import AppKit
import Observation
import RideauCore

/// Ce qui couvre le bureau : le fond d'ecran de chaque ecran, ou une couleur unie.
enum CoverStyle: String, CaseIterable, Sendable {
    case wallpaper, color

    var label: String {
        switch self {
        case .wallpaper: "Fond d\u{2019}\u{00E9}cran"
        case .color: "Couleur unie"
        }
    }
}

/// Reglages du rideau (UserDefaults, cles `Rideau...`).
@MainActor
@Observable
final class CurtainSettings {
    /// Nuancier de la couleur unie : teintes sobres de vialet.app, et le velours de Rideau.
    static let swatches: [(name: String, hex: UInt32)] = [
        ("Encre", 0x1E2227), ("Velours", 0x271223), ("Nuit", 0x0F1A2F),
        ("Ardoise", 0x4A5059), ("Papier", 0xF7F3EC), ("Pourpre", 0x8E1E80),
    ]

    var keepFrontmost: Bool { didSet { defaults.set(keepFrontmost, forKey: Brand.key("KeepFrontmost")) } }
    var keepFullScreen: Bool { didSet { defaults.set(keepFullScreen, forKey: Brand.key("KeepFullScreen")) } }
    /// Bundles toujours visibles, dans l'ordre d'ajout.
    var alwaysVisible: [String] { didSet { defaults.set(alwaysVisible, forKey: Brand.key("AlwaysVisible")) } }
    var coverDesktop: Bool { didSet { defaults.set(coverDesktop, forKey: Brand.key("CoverDesktop")) } }
    var coverStyle: CoverStyle { didSet { defaults.set(coverStyle.rawValue, forKey: Brand.key("CoverStyle")) } }
    var coverColor: UInt32 { didSet { defaults.set(Int(coverColor), forKey: Brand.key("CoverColor")) } }
    var showToast: Bool { didSet { defaults.set(showToast, forKey: Brand.key("Toast")) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: Brand.key(key)) as? Bool ?? fallback
        }
        keepFrontmost = bool("KeepFrontmost", true)
        keepFullScreen = bool("KeepFullScreen", true)
        alwaysVisible = defaults.stringArray(forKey: Brand.key("AlwaysVisible")) ?? CurtainPolicy.videoApps.map(\.id)
        coverDesktop = bool("CoverDesktop", true)
        coverStyle = CoverStyle(rawValue: defaults.string(forKey: Brand.key("CoverStyle")) ?? "") ?? .wallpaper
        coverColor = (defaults.object(forKey: Brand.key("CoverColor")) as? Int).map { UInt32(truncatingIfNeeded: $0) } ?? 0x1E2227
        showToast = bool("Toast", true)
    }

    func policy(ownPID: Int32) -> CurtainPolicy {
        CurtainPolicy(keepFrontmost: keepFrontmost, alwaysVisible: Set(alwaysVisible),
                      keepFullScreen: keepFullScreen, ownPID: ownPID)
    }

    func addAlwaysVisible(_ bundleID: String) {
        if !alwaysVisible.contains(bundleID) { alwaysVisible.append(bundleID) }
    }

    func removeAlwaysVisible(_ bundleID: String) {
        alwaysVisible.removeAll { $0 == bundleID }
    }

    var coverNSColor: NSColor { NSColor(hex: coverColor) }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
