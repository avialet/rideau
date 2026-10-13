import AppKit
import Observation
import RideauCore
import SwiftUI

extension MenuBarPresence {
    static let shared = MenuBarPresence(app: Brand.identity)
}

/// Etat partage de l'app : reglages et rideau.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    let settings: CurtainSettings
    let curtain: CurtainController
    /// Mode capture (DEBUG) : faux masquage, ni couverture, ni icone, etat dans un dossier jetable.
    let isCapture: Bool

    private init() {
        let settings = CurtainSettings()
        self.settings = settings
        #if DEBUG
        if SnapshotRequest.parse(prefix: Brand.name, arguments: CommandLine.arguments) != nil {
            isCapture = true
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("rideau-capture-\(UUID().uuidString)")
            curtain = CurtainController(hider: SnapshotHider(), settings: settings,
                                        file: BackstageFile(url: folder.appendingPathComponent("scene.json")),
                                        cover: nil, toast: CurtainToast(), statusItem: nil, live: false)
            return
        }
        #endif
        isCapture = false
        curtain = CurtainController(hider: SystemHider(), settings: settings, file: BackstageFile(url: BackstageFile.defaultURL()),
                                    cover: DesktopCover(settings: settings), toast: CurtainToast(),
                                    statusItem: LoweredStatusItem(), live: true)
    }

    /// Icone de la barre des menus : celle du choix de l'utilisateur, remplacee par l'icone du rideau baisse
    /// (un clic leve) tant que le rideau est baisse.
    var menuBarInserted: Binding<Bool> {
        Binding(get: { MenuBarPresence.shared.isInserted && !self.curtain.isDown },
                set: { if !self.curtain.isDown { MenuBarPresence.shared.isInserted = $0 } })
    }

    /// Nom lisible d'une app par son bundle : en cours, installee, visio connue, sinon l'identifiant.
    static func appName(_ bundleID: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = running.localizedName { return name }
        if let known = CurtainPolicy.knownName(bundleID) { return known }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    /// App installee ou en cours : les visios connues absentes de ce Mac ne s'affichent pas.
    static func isAvailable(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
            || NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
