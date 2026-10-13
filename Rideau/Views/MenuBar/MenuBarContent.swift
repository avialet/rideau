import RideauCore
import SwiftUI
import VialetKit

struct MenuBarContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let curtain = state.curtain
        Button(curtain.isDown ? "Lever le rideau" : "Baisser le rideau") { curtain.toggle() }
        Text(curtain.isDown ? Wording.backstage(curtain.backstage?.hidden.count ?? 0) : Wording.preview(curtain.preview.count))
        Divider()
        Button("Ouvrir la sc\u{00E8}ne") { WindowSummoner.show() }
        SettingsLink { Text("R\u{00E9}glages\u{2026}") }
        Button("\u{00C0} propos de \(Brand.displayName)") { AboutPanel.show(Brand.identity) }
        Divider()
        Button("Quitter \(Brand.displayName)") { NSApp.terminate(nil) }
    }
}
