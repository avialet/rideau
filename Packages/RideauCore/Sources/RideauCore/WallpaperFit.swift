import CoreGraphics

/// Mise a l'echelle du fond d'ecran (valeurs de `NSImageScaling`, lues dans `desktopImageOptions`).
public enum WallpaperScaling: Int, Sendable {
    case proportionallyDown = 0
    case axesIndependently = 1
    case none = 2
    case proportionallyUpOrDown = 3
}

/// Rectangle ou dessiner le fond d'ecran pour qu'il recouvre exactement celui de macOS.
public enum WallpaperFit {
    /// Options absentes : "Remplir l'ecran".
    public static let defaultScaling = WallpaperScaling.proportionallyUpOrDown
    public static let defaultAllowClipping = true

    public static func rect(image: CGSize, in bounds: CGRect, scaling: WallpaperScaling, allowClipping: Bool) -> CGRect {
        guard image.width > 0, image.height > 0 else { return bounds }
        let fit = min(bounds.width / image.width, bounds.height / image.height)
        let fill = max(bounds.width / image.width, bounds.height / image.height)
        let scale: CGFloat
        switch scaling {
        case .axesIndependently: return bounds
        case .none: scale = 1
        case .proportionallyUpOrDown: scale = allowClipping ? fill : fit
        case .proportionallyDown: scale = min(1, allowClipping ? fill : fit)
        }
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}
