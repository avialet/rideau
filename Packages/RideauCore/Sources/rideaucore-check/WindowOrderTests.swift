import CoreGraphics
import Foundation
import RideauCore

private func window(_ pid: Int, layer: Int = 0, x: Double = 0, y: Double = 0, w: Double = 800, h: Double = 600,
                    alpha: Double = 1) -> [String: Any] {
    [WindowOrder.ownerPIDKey: NSNumber(value: pid), WindowOrder.layerKey: NSNumber(value: layer),
     WindowOrder.alphaKey: NSNumber(value: alpha),
     WindowOrder.boundsKey: ["X": NSNumber(value: x), "Y": NSNumber(value: y),
                             "Width": NSNumber(value: w), "Height": NSNumber(value: h)] as [String: Any]]
}

let windowOrderTests: [Test] = [
    Test("rank : premier rang par pid, couche 0 seulement") {
        let windows = [window(1, layer: 25), window(2), window(3), window(2), window(4, layer: 3), window(5)]
        let ranks = WindowOrder.rank(windows)
        expectEqual(ranks[2], 0)
        expectEqual(ranks[3], 1)
        expectEqual(ranks[5], 2)
        expect(ranks[1] == nil && ranks[4] == nil)
    },
    Test("rank ignore les fenetres transparentes et les entrees incompletes") {
        let windows: [[String: Any]] = [window(1, alpha: 0), [WindowOrder.layerKey: NSNumber(value: 0)], window(2)]
        let ranks = WindowOrder.rank(windows)
        expectEqual(ranks[2], 0)
        expectEqual(ranks.count, 1)
    },
    Test("rank lit aussi des entiers Swift") {
        let windows: [[String: Any]] = [[WindowOrder.ownerPIDKey: 7, WindowOrder.layerKey: 0]]
        expectEqual(WindowOrder.rank(windows)[7], 0)
    },
    Test("fullScreenPIDs : fenetre couche 0 aux dimensions d'un ecran") {
        let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 1512, y: 0, width: 1920, height: 1080)]
        let windows = [window(1, w: 1512, h: 982), window(2, x: 1512, w: 1920, h: 1080), window(3, w: 1512, h: 950),
                       window(4, layer: 20, w: 1512, h: 982)]
        expectEqual(WindowOrder.fullScreenPIDs(windows, screens: screens), [1, 2])
    },
]
