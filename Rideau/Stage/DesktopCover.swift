import AppKit
import ImageIO
import RideauCore

/// Couvre les icones et widgets du bureau : une fenetre sans bord par ecran, juste au-dessus des icones
/// (bien en dessous des fenetres), sur tous les Spaces, qui dessine le fond d'ecran (ou une couleur unie)
/// et absorbe les clics sans activer Rideau. Rien n'est change dans le Finder.
@MainActor
final class DesktopCover {
    private let settings: CurtainSettings
    private let wallpapers = WallpaperCache()
    private var panels: [CGDirectDisplayID: CoverPanel] = [:]
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    /// Entre `show()` et `hide()`.
    private var active = false

    init(settings: CurtainSettings) {
        self.settings = settings
        wallpapers.onLoad = { [weak self] in self?.refresh() }
    }

    var isShown: Bool { !panels.isEmpty }

    func show() {
        active = true
        refresh()
        guard observers.isEmpty else { return }
        let local = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let screens = local.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                        queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        // Fond propre a chaque Space : relu a chaque changement.
        let space = workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil,
                                          queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        observers = [(local, screens), (workspace, space)]
    }

    func hide() {
        active = false
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
        for panel in panels.values { panel.orderOut(nil) }
        panels = [:]
    }

    /// Decode a l'avance les fonds d'ecran (le rideau tombe alors sans attendre l'image).
    func preload() {
        guard settings.coverDesktop, settings.coverStyle == .wallpaper else { return }
        for screen in NSScreen.screens {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) { wallpapers.load(url, maxPixels: Self.maxPixels(screen)) }
        }
    }

    /// Redessine les couvertures (ecrans, Space, reglages changes) ; les retire si le bureau n'est plus couvert.
    func refresh() {
        guard active else { return }
        guard settings.coverDesktop else {
            for panel in panels.values { panel.orderOut(nil) }
            panels = [:]
            return
        }
        var seen: Set<CGDirectDisplayID> = []
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            seen.insert(id)
            let panel = panels[id] ?? CoverPanel()
            panels[id] = panel
            panel.setFrame(screen.frame, display: false)
            panel.coverView.apply(content(for: screen))
            panel.orderFrontRegardless()
        }
        for (id, panel) in panels where !seen.contains(id) {
            panel.orderOut(nil)
            panels[id] = nil
        }
    }

    private func content(for screen: NSScreen) -> CoverContent {
        let solid = settings.coverNSColor
        guard settings.coverStyle == .wallpaper, let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return CoverContent(image: nil, pixelSize: .zero, fill: solid, scaling: .axesIndependently, allowClipping: false, scale: 1)
        }
        let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
        let scaling = (options[.imageScaling] as? NSNumber).flatMap { WallpaperScaling(rawValue: $0.intValue) }
            ?? WallpaperFit.defaultScaling
        let clipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? WallpaperFit.defaultAllowClipping
        let fill = (options[.fillColor] as? NSColor) ?? solid
        guard let wallpaper = wallpapers.image(for: url, maxPixels: Self.maxPixels(screen)) else {
            // Image absente ou illisible (Aerial, dossier, lecture refusee) : couleur unie.
            return CoverContent(image: nil, pixelSize: .zero, fill: solid, scaling: scaling, allowClipping: clipping, scale: 1)
        }
        return CoverContent(image: wallpaper.image, pixelSize: wallpaper.pixelSize, fill: fill, scaling: scaling,
                            allowClipping: clipping, scale: screen.backingScaleFactor)
    }

    private static func maxPixels(_ screen: NSScreen) -> Int {
        Int(max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor * 1.5)
    }
}

/// Ce que dessine une couverture.
struct CoverContent {
    var image: CGImage?
    /// Taille d'origine de l'image, en pixels (avant reduction).
    var pixelSize: CGSize
    var fill: NSColor
    var scaling: WallpaperScaling
    var allowClipping: Bool
    var scale: CGFloat
}

/// Panneau sans bord, jamais cle ni principal, qui n'active pas Rideau quand on clique dessus.
final class CoverPanel: NSPanel {
    let coverView = CoverView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = true
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        ignoresMouseEvents = false
        backgroundColor = .black
        contentView = coverView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Dessine le fond d'ecran cadre comme macOS (remplir, ajuster, etirer, centrer) sur sa couleur de fond.
final class CoverView: NSView {
    private var content = CoverContent(image: nil, pixelSize: .zero, fill: .black, scaling: .axesIndependently,
                                       allowClipping: false, scale: 1)

    func apply(_ content: CoverContent) {
        self.content = content
        needsDisplay = true
    }

    override var isOpaque: Bool { true }

    /// Les clics s'arretent ici : on ne selectionne pas une icone cachee.
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        content.fill.setFill()
        bounds.fill()
        guard let image = content.image, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let points = CGSize(width: content.pixelSize.width / content.scale, height: content.pixelSize.height / content.scale)
        let rect = WallpaperFit.rect(image: points, in: bounds, scaling: content.scaling, allowClipping: content.allowClipping)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: rect)
    }
}

/// Fonds d'ecran decodes hors du fil principal (ImageIO), reduits a la taille utile.
@MainActor
final class WallpaperCache {
    struct Wallpaper: @unchecked Sendable {
        let image: CGImage
        let pixelSize: CGSize
    }

    var onLoad: (() -> Void)?
    private var images: [URL: Wallpaper] = [:]
    private var failed: Set<URL> = []
    private var loading: Set<URL> = []

    /// Image deja decodee ; sinon lance son decodage et rend nil (couleur en attendant).
    func image(for url: URL, maxPixels: Int) -> Wallpaper? {
        if let image = images[url] { return image }
        load(url, maxPixels: maxPixels)
        return nil
    }

    func load(_ url: URL, maxPixels: Int) {
        guard images[url] == nil, !failed.contains(url), !loading.contains(url) else { return }
        loading.insert(url)
        Task.detached(priority: .userInitiated) {
            let wallpaper = Self.decode(url, maxPixels: maxPixels)
            await MainActor.run {
                self.loading.remove(url)
                if let wallpaper { self.images[url] = wallpaper } else { self.failed.insert(url) }
                if wallpaper != nil { self.onLoad?() }
            }
        }
    }

    nonisolated private static func decode(_ url: URL, maxPixels: Int) -> Wallpaper? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let size = width > 0 && height > 0 ? CGSize(width: width, height: height)
                                            : CGSize(width: image.width, height: image.height)
        return Wallpaper(image: image, pixelSize: size)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
