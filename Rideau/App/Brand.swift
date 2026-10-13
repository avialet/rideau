import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom, ses teintes et son glyphe.
enum Brand {
    static let name = "Rideau"
    static let displayName = "Rideau"
    /// Teintes de l'affiche (sites, plaques, DMG, interface), calculees par scripts/teintes.py :
    /// texte `deep` sur `background`. Une teinte par ligne `cle: 0x...` (lue par les scripts du socle).
    static let palette = AccentPalette(accent: 0x8E1E80, background: 0xB84BAA,
                                       deep: 0x0F000D, pale: 0xFEEBFA,
                                       night: 0x271223, nightInk: 0xF1C9E8)
    /// Pictogramme de la plaque : sous-ensemble SVG absolu (M L H V C Q Z), boite 0-100, trait non rempli.
    /// Tringle et deux pans retenus : le rideau leve.
    static let glyph = "M 14 20 H 86 M 24 20 V 82 M 76 20 V 82 M 46 20 C 44 42 32 52 24 58 M 54 20 C 56 42 68 52 76 58"
    /// Rideau ferme : icone de barre des menus tant que le rideau est baisse.
    static let loweredGlyph = "M 14 20 H 86 M 24 20 V 82 M 50 20 V 82 M 76 20 V 82"
    /// Trait du glyphe en `deep` plutot qu'en blanc (accent trop clair pour un trait blanc).
    static let strokeDeep = false
    static let identity = AppIdentity(name: name, displayName: displayName, repository: "avialet/rideau",
                                      bundleIdentifier: "fr.vialet.rideau", palette: palette, glyph: glyph,
                                      strokeDeep: strokeDeep)
    static let updater = UpdaterConfiguration(identity)

    /// Cles UserDefaults, prefixees par le nom de l'app.
    static func key(_ suffix: String) -> String { identity.key(suffix) }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    /// Opt-Maj-Cmd-Espace : libre dans le portefeuille (Pico, Allege, Pince, Brouillon, Chuchote, Range, Eveil,
    /// Lanterne ont le leur).
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName,
                                         initial: .space([.option, .shift, .command]))
}
