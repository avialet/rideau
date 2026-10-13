import AppKit
import Observation
import RideauCore
import SwiftUI
import VialetKit

/// Pastille sans focus en bas de l'ecran, 1,2 s : "Rideau baisse - 7 apps en coulisses".
@MainActor
final class CurtainToast {
    enum Message: Equatable {
        case lowered(count: Int)
        case raised(count: Int)
    }

    @Observable
    final class Model {
        var message: Message = .lowered(count: 0)
    }

    static let size = CGSize(width: 380, height: 64)
    static let margin: CGFloat = 16

    private let model = Model()
    private lazy var panel = FloatingPanelController(
        size: CGSize(width: Self.size.width + Self.margin * 2, height: Self.size.height + Self.margin * 2),
        takesFocus: false, placement: .bottom) { [model] in ToastView(model: model) }
    private var hideTask: Task<Void, Never>?

    /// `duration` nil : reste affichee (mode capture).
    func show(_ message: Message, duration: Duration? = .milliseconds(1200)) {
        model.message = message
        panel.show()
        hideTask?.cancel()
        guard let duration else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.panel.hide()
        }
    }
}

struct ToastView: View {
    let model: CurtainToast.Model

    var body: some View {
        PanelCard {
            HStack(spacing: Theme.Space.m) {
                Image(nsImage: GlyphImage.plate(Brand.palette, glyph: lowered ? Brand.loweredGlyph : Brand.glyph, pixels: 80))
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(lowered ? "Rideau baiss\u{00E9}" : "Rideau lev\u{00E9}")
                        .font(Theme.display(16))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(Theme.ui(12.5))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: Theme.Space.s)
                KeyHint(HotKeyController.shared.shortcut.display, lowered ? "lever" : "baisser")
                    .fixedSize()
            }
            .padding(.horizontal, Theme.Space.l)
            .frame(width: CurtainToast.size.width, height: CurtainToast.size.height)
        }
        .padding(CurtainToast.margin)
    }

    private var lowered: Bool {
        if case .lowered = model.message { return true }
        return false
    }

    private var detail: String {
        switch model.message {
        case .lowered(let count): Wording.backstage(count)
        case .raised(let count): Wording.returned(count)
        }
    }
}

/// Icone de barre des menus tant que le rideau est baisse (meme quand Vialet range les apps) :
/// le rideau ferme, et un clic le leve.
@MainActor
final class LoweredStatusItem: NSObject {
    private var item: NSStatusItem?
    private var action: (() -> Void)?

    func show(action: @escaping () -> Void) {
        self.action = action
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = GlyphImage.template(Brand.loweredGlyph)
        item.button?.toolTip = "Lever le rideau (\(HotKeyController.shared.shortcut.display))"
        item.button?.setAccessibilityLabel("Lever le rideau")
        item.button?.target = self
        item.button?.action = #selector(clicked)
        self.item = item
    }

    func hide() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    @objc private func clicked() { action?() }
}
