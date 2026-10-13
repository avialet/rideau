import CoreGraphics
import Foundation

/// Lecture des dictionnaires de `CGWindowListCopyWindowInfo` (de l'avant vers l'arriere). Le pid, la couche,
/// l'opacite et le cadre se lisent sans autorisation ; seul le titre exigerait l'Enregistrement de l'ecran.
public enum WindowOrder {
    public static let ownerPIDKey = "kCGWindowOwnerPID"
    public static let layerKey = "kCGWindowLayer"
    public static let alphaKey = "kCGWindowAlpha"
    public static let boundsKey = "kCGWindowBounds"

    /// Rang de chaque app : ordre de sa premiere fenetre ordinaire (couche 0, visible), 0 devant.
    public static func rank(_ windows: [[String: Any]]) -> [Int32: Int] {
        var ranks: [Int32: Int] = [:]
        for window in windows {
            guard let pid = ordinaryOwner(window), ranks[pid] == nil else { continue }
            ranks[pid] = ranks.count
        }
        return ranks
    }

    /// Apps dont une fenetre ordinaire occupe exactement un ecran (plein ecran), cadres en coordonnees
    /// globales de CoreGraphics (origine en haut a gauche, comme `CGDisplayBounds`).
    public static func fullScreenPIDs(_ windows: [[String: Any]], screens: [CGRect]) -> Set<Int32> {
        var pids: Set<Int32> = []
        for window in windows {
            guard let pid = ordinaryOwner(window), let frame = bounds(window) else { continue }
            if screens.contains(where: { $0.equalTo(frame) }) { pids.insert(pid) }
        }
        return pids
    }

    private static func ordinaryOwner(_ window: [String: Any]) -> Int32? {
        guard let pid = number(window[ownerPIDKey]), let layer = number(window[layerKey]), layer.intValue == 0 else { return nil }
        if let alpha = number(window[alphaKey]), alpha.doubleValue <= 0 { return nil }
        return pid.int32Value
    }

    private static func bounds(_ window: [String: Any]) -> CGRect? {
        guard let dict = window[boundsKey] as? [String: Any],
              let x = number(dict["X"]), let y = number(dict["Y"]),
              let w = number(dict["Width"]), let h = number(dict["Height"]) else { return nil }
        return CGRect(x: x.doubleValue, y: y.doubleValue, width: w.doubleValue, height: h.doubleValue)
    }

    private static func number(_ value: Any?) -> NSNumber? {
        switch value {
        case let n as NSNumber: return n
        case let i as Int: return NSNumber(value: i)
        case let i as Int32: return NSNumber(value: i)
        case let d as Double: return NSNumber(value: d)
        default: return nil
        }
    }
}
