import SwiftUI
import VialetKit

@main
struct RideauApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState.shared

    /// Teintes de l'app avant le premier rendu (et police Bricolage Grotesque des titres).
    init() { Theme.configure(Brand.palette) }

    var body: some Scene {
        Window(Brand.displayName, id: "main") {
            SceneWindow()
                .environment(state)
                .fontDesign(.rounded)
                .frame(minWidth: 800, minHeight: 560)
                .onAppear { AppearanceChoice.current(defaultsKey: Brand.key("Appearance")).apply(defaultsKey: Brand.key("Appearance")) }
                .captureOpenWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 940, height: 700)
        .commands {
            AboutCommands(identity: Brand.identity)
            UpdateCommands(updater: .shared)
            CurtainCommands(curtain: state.curtain)
        }

        Settings {
            SettingsView().environment(state)
        }

        MenuBarExtra(isInserted: state.menuBarInserted) {
            MenuBarContent().environment(state)
        } label: {
            MenuBarIcon(glyph: Brand.glyph)
        }
    }
}

struct CurtainCommands: Commands {
    let curtain: CurtainController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandMenu("Rideau") {
            Button(curtain.isDown ? "Lever le rideau" : "Baisser le rideau") { curtain.toggle() }
        }
    }
}
