import SwiftUI
import VialetKit

/// Reglages : les cartes standard du kit, puis la pastille propre a Rideau. Ce que le rideau cache se regle
/// dans la Scene.
struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var settings = state.settings
        SettingsScreen(app: Brand.identity, hotKey: HotKeyController.shared, updater: Updater.shared,
                       menuBar: MenuBarPresence.shared,
                       hotKeyHint: "Depuis n\u{2019}importe quelle app : baisse le rideau, puis le l\u{00E8}ve.",
                       alwaysOnHint: "Fermer la fen\u{00EA}tre ne quitte pas Rideau : le raccourci reste actif. Quitter Rideau (\u{2318}Q) l\u{00E8}ve toujours le rideau.",
                       width: 480) {
            SettingsCard(icon: "capsule.fill", color: Theme.accent, title: "Pastille") {
                Toggle("Annoncer le rideau en bas de l\u{2019}\u{00E9}cran", isOn: $settings.showToast)
                Text("Une seconde, sans prendre le focus. Les spectateurs d\u{2019}un partage d\u{2019}\u{00E9}cran peuvent la voir.")
                    .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
