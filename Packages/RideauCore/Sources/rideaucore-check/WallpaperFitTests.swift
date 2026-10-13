import CoreGraphics
import RideauCore

private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

let wallpaperFitTests: [Test] = [
    Test("remplir : proportionnel, rogne, centre") {
        let r = WallpaperFit.rect(image: CGSize(width: 800, height: 800), in: screen, scaling: .proportionallyUpOrDown, allowClipping: true)
        expectEqual(r, CGRect(x: 0, y: -300, width: 1600, height: 1600))
    },
    Test("ajuster : proportionnel, entier, centre") {
        let r = WallpaperFit.rect(image: CGSize(width: 800, height: 800), in: screen, scaling: .proportionallyUpOrDown, allowClipping: false)
        expectEqual(r, CGRect(x: 300, y: 0, width: 1000, height: 1000))
    },
    Test("etirer : tout l'ecran") {
        let r = WallpaperFit.rect(image: CGSize(width: 10, height: 30), in: screen, scaling: .axesIndependently, allowClipping: false)
        expectEqual(r, screen)
    },
    Test("centrer : taille d'origine") {
        let r = WallpaperFit.rect(image: CGSize(width: 400, height: 200), in: screen, scaling: .none, allowClipping: false)
        expectEqual(r, CGRect(x: 600, y: 400, width: 400, height: 200))
    },
    Test("reduire seulement : jamais agrandi") {
        let small = WallpaperFit.rect(image: CGSize(width: 400, height: 200), in: screen, scaling: .proportionallyDown, allowClipping: false)
        expectEqual(small, CGRect(x: 600, y: 400, width: 400, height: 200))
        let big = WallpaperFit.rect(image: CGSize(width: 3200, height: 1000), in: screen, scaling: .proportionallyDown, allowClipping: false)
        expectEqual(big, CGRect(x: 0, y: 250, width: 1600, height: 500))
    },
    Test("ecran decale et image vide") {
        let offset = CGRect(x: 1600, y: 0, width: 1000, height: 1000)
        let r = WallpaperFit.rect(image: CGSize(width: 500, height: 500), in: offset, scaling: .proportionallyUpOrDown, allowClipping: true)
        expectEqual(r, offset)
        expectEqual(WallpaperFit.rect(image: .zero, in: offset, scaling: .none, allowClipping: true), offset)
    },
    Test("options absentes : remplir") {
        expectEqual(WallpaperScaling(rawValue: 3), .proportionallyUpOrDown)
        expectEqual(WallpaperFit.defaultScaling, .proportionallyUpOrDown)
        expect(WallpaperFit.defaultAllowClipping)
    },
]
