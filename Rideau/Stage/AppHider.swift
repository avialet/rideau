import AppKit
import CoreGraphics
import RideauCore

/// Ce que le rideau fait aux autres apps. `SystemHider` agit pour de vrai (NSRunningApplication, aucune
/// autorisation) ; le mode capture lui substitue un faux qui ne masque rien.
@MainActor
protocol Hider: AnyObject {
    /// Apps en cours, avec leur rang a l'ecran et leur plein ecran.
    func runningApps() -> [AppSnapshot]
    /// App ordinaire au premier plan, hors Rideau (la derniere active si Rideau est devant).
    func frontmostPID() -> Int32?
    func hide(_ app: AppSnapshot) -> Bool
    func unhide(_ app: AppSnapshot) -> Bool
    func activate(_ app: AppSnapshot)
    func icon(for app: AppSnapshot) -> NSImage?
}

@MainActor
final class SystemHider: Hider {
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    /// Derniere app ordinaire active autre que Rideau : celle a garder quand on baisse depuis la Scene ou une URL.
    private var lastForeignFront: Int32?
    private var observer: NSObjectProtocol?

    init() {
        if let front = NSWorkspace.shared.frontmostApplication, isForeignRegular(front) {
            lastForeignFront = front.processIdentifier
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let pid = app?.processIdentifier
            let regular = app?.activationPolicy == .regular
            MainActor.assumeIsolated {
                guard let self, let pid, regular, pid != self.ownPID else { return }
                self.lastForeignFront = pid
            }
        }
    }

    func runningApps() -> [AppSnapshot] {
        let ranks = WindowReader.ranks()
        let fullScreen = WindowReader.fullScreenPIDs()
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard !app.isTerminated else { return nil }
            let pid = app.processIdentifier
            return AppSnapshot(pid: pid, bundleID: app.bundleIdentifier,
                               name: app.localizedName ?? app.bundleIdentifier ?? "App",
                               isHidden: app.isHidden, isRegular: app.activationPolicy == .regular,
                               isFullScreen: fullScreen.contains(pid), rank: ranks[pid])
        }
    }

    func frontmostPID() -> Int32? {
        if let front = NSWorkspace.shared.frontmostApplication, isForeignRegular(front) {
            return front.processIdentifier
        }
        guard let pid = lastForeignFront, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
            return nil
        }
        return pid
    }

    func hide(_ app: AppSnapshot) -> Bool { running(app)?.hide() ?? false }

    func unhide(_ app: AppSnapshot) -> Bool { running(app)?.unhide() ?? false }

    /// Activation cooperative : Rideau cede la main s'il l'a, puis l'app la reprend.
    func activate(_ app: AppSnapshot) {
        guard let target = running(app) else { return }
        if NSApp.isActive { NSApp.yieldActivation(to: target) }
        if !target.activate(from: .current, options: []) { _ = target.activate(options: []) }
    }

    func icon(for app: AppSnapshot) -> NSImage? {
        NSRunningApplication(processIdentifier: app.pid)?.icon
    }

    /// L'instance exacte : meme pid, meme bundle, toujours en vie.
    private func running(_ app: AppSnapshot) -> NSRunningApplication? {
        guard let running = NSRunningApplication(processIdentifier: app.pid), !running.isTerminated,
              running.bundleIdentifier == app.bundleID else { return nil }
        return running
    }

    private func isForeignRegular(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier != ownPID && app.activationPolicy == .regular
    }
}

/// Fenetres a l'ecran (CGWindowList, sans autorisation : ni titre ni contenu, seulement pid, couche, cadre).
enum WindowReader {
    static func ranks() -> [Int32: Int] {
        WindowOrder.rank(windows([.optionOnScreenOnly, .excludeDesktopElements]))
    }

    /// Plein ecran, sur tous les Spaces (`optionAll`) : une fenetre ordinaire aux dimensions d'un ecran.
    static func fullScreenPIDs() -> Set<Int32> {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        let screens = displays.prefix(Int(count)).map { CGDisplayBounds($0) }
        return WindowOrder.fullScreenPIDs(windows([.optionAll, .excludeDesktopElements]), screens: screens)
    }

    private static func windows(_ options: CGWindowListOption) -> [[String: Any]] {
        CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    }
}
