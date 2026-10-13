#if DEBUG
import AppKit
import RideauCore
import VialetKit

/// Mode capture sans ecran : `Rideau -RideauSnapshot <dossier> [-RideauSnapshotAppearance dark]
/// [-RideauSnapshotOnly a,b] [-RideauSnapshotSize 1000x720]`. Faux masquage (graine de 9 apps fictives,
/// rien n'est masque pour de vrai), ni couverture du bureau, ni icone, etat dans un dossier jetable.
/// Ecrit `mainWindow` (leve), `settings`, `about`, `floatingPanel` (pastille), `update`, `mainWindowDown`
/// (baisse) et `reprise` (retrouve baisse apres un arret), `-sombre` en sombre, puis quitte.
extension AppDelegate {
    func runSnapshotIfRequested() -> Bool {
        guard SnapshotRequest.parse(prefix: Brand.name, arguments: CommandLine.arguments) != nil else { return false }
        let curtain = AppState.shared.curtain
        let toast = CurtainToast()
        curtain.refreshPreview()
        let panel = SnapshotScenario("floatingPanel") {
            toast.show(.lowered(count: 7), duration: nil)
            try await Task.sleep(for: .milliseconds(700))
            return NSApp.windows.first { $0 is FloatingPanel && $0.isVisible }
        }
        let down = SnapshotScenario("mainWindowDown") {
            NSApp.windows.first { $0 is FloatingPanel }?.orderOut(nil)
            curtain.lower()
            try await Task.sleep(for: .seconds(2))
            return WindowSummoner.mainWindow
        }
        let recovered = SnapshotScenario("reprise") {
            curtain.snapshotRecover()
            try await Task.sleep(for: .seconds(1))
            return WindowSummoner.mainWindow
        }
        let standard = SnapshotRunner.standardScenarios(mainWindow: { WindowSummoner.mainWindow }, identity: Brand.identity)
        return SnapshotRunner.runIfRequested(prefix: Brand.name, scenarios: standard + [panel, down, recovered])
    }
}

/// Graine neutre : neuf apps fictives (noms generiques, icones dessinees), aucune vraie app touchee.
@MainActor
final class SnapshotHider: Hider {
    private struct Fake {
        var app: AppSnapshot
        let symbol: String
        let color: UInt32
    }

    private var apps: [Fake] = [
        Fake(app: .init(pid: 501, bundleID: "fr.exemple.navigateur", name: "Navigateur", isHidden: false, isRegular: true, rank: 0),
             symbol: "safari", color: 0x2F6FEB),
        Fake(app: .init(pid: 502, bundleID: "us.zoom.xos", name: "Visio", isHidden: false, isRegular: true, rank: 1),
             symbol: "video.fill", color: 0x2E9D6E),
        Fake(app: .init(pid: 503, bundleID: "fr.exemple.courrier", name: "Courrier", isHidden: false, isRegular: true, rank: 2),
             symbol: "envelope.fill", color: 0x3D8BF2),
        Fake(app: .init(pid: 504, bundleID: "fr.exemple.messagerie", name: "Messagerie", isHidden: false, isRegular: true, rank: 3),
             symbol: "bubble.left.and.bubble.right.fill", color: 0x34B65A),
        Fake(app: .init(pid: 505, bundleID: "fr.exemple.agenda", name: "Agenda", isHidden: false, isRegular: true, rank: 4),
             symbol: "calendar", color: 0xE5484D),
        Fake(app: .init(pid: 506, bundleID: "fr.exemple.notes", name: "Carnet", isHidden: false, isRegular: true, rank: 5),
             symbol: "note.text", color: 0xF0A020),
        Fake(app: .init(pid: 507, bundleID: "fr.exemple.tableur", name: "Tableur", isHidden: false, isRegular: true, rank: 6),
             symbol: "tablecells.fill", color: 0x1F8A5B),
        Fake(app: .init(pid: 508, bundleID: "fr.exemple.musique", name: "Musique", isHidden: false, isRegular: true),
             symbol: "music.note", color: 0xEC6A5C),
        Fake(app: .init(pid: 509, bundleID: "fr.exemple.galerie", name: "Galerie", isHidden: false, isRegular: true),
             symbol: "photo.on.rectangle", color: 0x8B78E6),
    ]
    private var icons: [Int32: NSImage] = [:]

    func runningApps() -> [AppSnapshot] { apps.map(\.app) }
    func frontmostPID() -> Int32? { 501 }

    func hide(_ app: AppSnapshot) { set(app.pid, hidden: true) }
    func unhide(_ app: AppSnapshot) { set(app.pid, hidden: false) }
    func activate(_ app: AppSnapshot) {}

    func icon(for app: AppSnapshot) -> NSImage? {
        if let icon = icons[app.pid] { return icon }
        guard let fake = apps.first(where: { $0.app.pid == app.pid }) else { return nil }
        let icon = Self.drawIcon(symbol: fake.symbol, color: NSColor(hex: fake.color))
        icons[app.pid] = icon
        return icon
    }

    private func set(_ pid: Int32, hidden: Bool) {
        guard let i = apps.firstIndex(where: { $0.app.pid == pid }) else { return }
        apps[i].app.isHidden = hidden
    }

    /// Carre arrondi colore et symbole blanc, a la maniere d'une icone d'app.
    private static func drawIcon(symbol: String, color: NSColor) -> NSImage {
        let side: CGFloat = 64
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let plate = rect.insetBy(dx: 4, dy: 4)
            color.setFill()
            NSBezierPath(roundedRect: plate, xRadius: plate.width * 0.2245, yRadius: plate.width * 0.2245).fill()
            let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
                .applying(.init(paletteColors: [.white]))
            if let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let size = glyph.size
                glyph.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                      width: size.width, height: size.height))
            }
            return true
        }
    }
}
#endif
