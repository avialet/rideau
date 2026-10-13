import AppKit
import RideauCore
import VialetKit

extension AppActions {
    static let shared = AppActions(Brand.identity, open: { WindowSummoner.show() },
                                   checkForUpdates: { WindowSummoner.show(); Updater.shared.check() })
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Mode capture : ni raccourci, ni reseau, ni masquage reel.
        if runSnapshotIfRequested() { return }
        #endif
        let curtain = AppState.shared.curtain
        curtain.start()
        HotKeyController.shared.start { AppState.shared.curtain.toggle() }
        registerActions()
        AppActions.shared.publish()
        liftOnSignals()
        // Rideau retrouve baisse (arret inattendu) : la Scene propose de le lever.
        if curtain.machine.recovered { WindowSummoner.show() }
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
        }
    }

    /// Actions rapides pour Vialet, Raccourcis et les automatisations (`rideau://basculer`, `baisser`, `lever`).
    private func registerActions() {
        let shortcut = HotKeyController.shared.shortcut.display
        AppActions.shared.register(AppAction("basculer", title: "Baisser ou lever le rideau", symbol: "theatermasks",
                                             shortcut: shortcut)) { AppState.shared.curtain.toggle() }
        AppActions.shared.register(AppAction("baisser", title: "Baisser le rideau", symbol: "eye.slash")) {
            AppState.shared.curtain.lower()
        }
        AppActions.shared.register(AppAction("lever", title: "Lever le rideau", symbol: "eye")) {
            AppState.shared.curtain.raise()
        }
    }

    /// `kill` (SIGTERM) ou Ctrl-C : on leve le rideau avant de partir, comme pour Cmd-Q.
    private func liftOnSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { MainActor.assumeIsolated { NSApp.terminate(nil) } }
            source.resume()
            signalSources.append(source)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppActions.shared.handle(urls)
    }

    /// Quitter Rideau leve toujours le rideau.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppState.shared.curtain.raiseNow()
        return .terminateNow
    }

    /// L'app reste disponible (raccourci global, barre des menus) fenetre fermee.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowSummoner.show() }
        return true
    }
}
