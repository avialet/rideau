import AppKit
import Observation
import RideauCore

/// Orchestration du rideau : baisser (masquer les autres apps, couvrir le bureau, sauvegarder ce qui a ete
/// masque), lever (reafficher exactement ces apps, de l'arriere vers l'avant, rendre la main), et reprise
/// apres un arret inattendu (etat sauvegarde lu au lancement).
@MainActor
@Observable
final class CurtainController {
    private(set) var machine: CurtainMachine
    /// Ce que Rideau a mis en coulisses (nil rideau leve).
    private(set) var backstage: Backstage?
    /// Apps que le rideau masquerait maintenant (Scene, menu).
    private(set) var preview: [AppSnapshot] = []
    /// Apps en plein ecran laissees telles quelles.
    private(set) var fullScreenKept: [AppSnapshot] = []

    var state: CurtainState { machine.state }
    var isDown: Bool { machine.state.isDown || machine.state == .raising }

    @ObservationIgnored let hider: Hider
    @ObservationIgnored let settings: CurtainSettings
    @ObservationIgnored private let file: BackstageFile
    @ObservationIgnored private let cover: DesktopCover?
    @ObservationIgnored private let toast: CurtainToast?
    @ObservationIgnored private let statusItem: LoweredStatusItem?
    @ObservationIgnored private let ownPID = ProcessInfo.processInfo.processIdentifier
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    /// Faux en mode capture : ni fenetre fermee, ni activation.
    @ObservationIgnored private let live: Bool

    init(hider: Hider, settings: CurtainSettings, file: BackstageFile, cover: DesktopCover?, toast: CurtainToast?,
         statusItem: LoweredStatusItem?, live: Bool) {
        self.hider = hider
        self.settings = settings
        self.file = file
        self.cover = cover
        self.toast = toast
        self.statusItem = statusItem
        self.live = live
        let saved = file.read()
        machine = CurtainMachine(recovering: saved != nil)
        backstage = saved
    }

    /// Au lancement : suivi des apps, couverture prete, et icone du rideau baisse si on le retrouve baisse.
    func start() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                                          NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
                                          NSWorkspace.didActivateApplicationNotification]
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                let released = note.name == NSWorkspace.didUnhideApplicationNotification
                    || note.name == NSWorkspace.didTerminateApplicationNotification
                MainActor.assumeIsolated {
                    if released, let pid { self?.release(pid) }
                    self?.refreshPreview()
                }
            })
        }
        refreshPreview()
        cover?.preload()
        if machine.recovered { statusItem?.show { [weak self] in self?.raise() } }
    }

    // MARK: Commandes

    func toggle() { run(machine.toggle(now: .now)) }
    func lower() { run(machine.request(.lower, now: .now)) }
    func raise() { run(machine.request(.raise, now: .now)) }

    private func run(_ command: CurtainCommand?) {
        switch command {
        case .lower: performLower()
        case .raise: Task { await performRaise() }
        case nil: break
        }
    }

    func refreshPreview() {
        let apps = hider.runningApps()
        let policy = settings.policy(ownPID: ownPID)
        preview = Stage.planLower(apps: apps, frontmostPID: hider.frontmostPID(), policy: policy)
        fullScreenKept = policy.keepFullScreen ? apps.filter { $0.isRegular && !$0.isHidden && $0.isFullScreen } : []
    }

    // MARK: Baisser

    private func performLower() {
        let apps = hider.runningApps()
        let frontPID = hider.frontmostPID()
        let plan = Stage.planLower(apps: apps, frontmostPID: frontPID, policy: settings.policy(ownPID: ownPID))
        let stage = Backstage(loweredAt: .now, frontmost: apps.first { $0.pid == frontPID }, hidden: plan)
        // Sauvegarde avant de masquer : un plantage au milieu laisse de quoi tout lever.
        try? file.write(stage)
        for app in plan { hider.hide(app) }
        backstage = stage
        machine.finish()
        cover?.show()
        statusItem?.show { [weak self] in self?.raise() }
        if live {
            // La Scene s'efface (rien de Rideau a l'ecran pendant la presentation) ; baisse depuis la Scene ou
            // une URL : l'app presentee reprend la main.
            WindowSummoner.mainWindow?.close()
            if NSApp.isActive, let front = stage.frontmost, !plan.contains(where: { $0.pid == front.pid }) {
                hider.activate(front)
            }
        }
        if settings.showToast { toast?.show(.lowered(count: plan.count)) }
        refreshPreview()
        Task { await verifyLowered(stage.loweredAt) }
    }

    /// Un instant apres : les apps restees visibles sont des refus, retirees de ce que l'on reaffichera.
    private func verifyLowered(_ loweredAt: Date) async {
        try? await Task.sleep(for: .milliseconds(900))
        guard machine.state == .lowered, let stage = backstage, stage.loweredAt == loweredAt else { return }
        let next = stage.refusing(Stage.refusals(backstage: stage, running: hider.runningApps()))
        if next != stage {
            backstage = next
            try? file.write(next)
        }
        trace("baisse : masquees \(next.hidden.map(\.name)), refus \(next.refused), devant \(next.frontmost?.name ?? "-")")
    }

    // MARK: Lever

    private func performRaise() async {
        statusItem?.hide()
        var count = 0
        if let stage = backstage {
            let plan = Stage.planRaise(backstage: stage, running: hider.runningApps(), afterCrash: machine.recovered)
            for (index, app) in plan.unhide.enumerated() {
                if index > 0 { try? await Task.sleep(for: .milliseconds(40)) }
                hider.unhide(app)
            }
            count = plan.unhide.count
            if let front = plan.activate {
                try? await Task.sleep(for: .milliseconds(80))
                hider.activate(front)
            }
            trace("leve : reaffichees \(plan.unhide.map(\.name)), parties \(plan.gone.map(\.name)), reactivee \(plan.activate?.name ?? "-")")
        }
        // Couverture retiree apres la restitution : les icones du bureau ne clignotent pas entre deux apps.
        cover?.hide()
        file.erase()
        backstage = nil
        machine.finish()
        if settings.showToast { toast?.show(.raised(count: count)) }
        refreshPreview()
    }

    /// Lever sans attendre (fin de Rideau) : tout ce qui a ete masque revient.
    func raiseNow() {
        guard machine.state != .raised || backstage != nil else { return }
        statusItem?.hide()
        if let stage = backstage {
            let plan = Stage.planRaise(backstage: stage, running: hider.runningApps(), afterCrash: machine.recovered)
            for app in plan.unhide { hider.unhide(app) }
            if let front = plan.activate { hider.activate(front) }
        }
        cover?.hide()
        file.erase()
        backstage = nil
    }

    /// L'utilisateur a reaffiche (ou quitte) une app en coulisses : elle ne nous appartient plus.
    private func release(_ pid: Int32) {
        guard machine.state == .lowered, let stage = backstage, stage.hidden.contains(where: { $0.pid == pid }) else { return }
        let next = stage.releasing(pid: pid)
        backstage = next
        try? file.write(next)
    }

    /// Journal des essais reels (DEBUG, `RIDEAU_TRACE=<fichier>`).
    private func trace(_ line: String) {
        #if DEBUG
        guard let path = ProcessInfo.processInfo.environment["RIDEAU_TRACE"],
              let handle = FileHandle(forWritingAtPath: path) ?? {
                  FileManager.default.createFile(atPath: path, contents: nil)
                  return FileHandle(forWritingAtPath: path)
              }() else { return }
        handle.seekToEndOfFile()
        handle.write(Data((line + "\n").utf8))
        try? handle.close()
        #endif
    }

    #if DEBUG
    /// Mode capture : rideau retrouve baisse apres un arret inattendu.
    func snapshotRecover() {
        let apps = hider.runningApps()
        let plan = Stage.planLower(apps: apps, frontmostPID: hider.frontmostPID(), policy: settings.policy(ownPID: ownPID))
        backstage = Backstage(loweredAt: Date(timeIntervalSinceNow: -1800), frontmost: nil, hidden: backstage?.hidden ?? plan)
        machine = CurtainMachine(recovering: true)
    }
    #endif
}
