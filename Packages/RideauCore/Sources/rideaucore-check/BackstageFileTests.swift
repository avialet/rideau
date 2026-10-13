import Foundation
import RideauCore

private func tempURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("rideau-check-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("scene.json")
}

private let sample = Backstage(
    loweredAt: Date(timeIntervalSince1970: 1_800_000_000),
    frontmost: AppSnapshot(pid: 10, bundleID: "com.apple.Safari", name: "Safari", isHidden: false, isRegular: true,
                           isFullScreen: false, rank: 0),
    hidden: [AppSnapshot(pid: 11, bundleID: "com.apple.mail", name: "Mail", isHidden: false, isRegular: true,
                         isFullScreen: false, rank: 1)],
    refused: ["Agent"])

let backstageFileTests: [Test] = [
    Test("ecriture puis lecture a l'identique, dossier cree") {
        let file = BackstageFile(url: tempURL())
        try file.write(sample)
        expectEqual(file.read(), sample)
        try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent())
    },
    Test("lecture sans fichier : rien") {
        expect(BackstageFile(url: tempURL()).read() == nil)
    },
    Test("effacement : plus rien a lire, sans erreur si absent") {
        let file = BackstageFile(url: tempURL())
        try file.write(sample)
        file.erase()
        expect(file.read() == nil)
        file.erase()
        try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent())
    },
    Test("fichier illisible ou version future : rien") {
        let file = BackstageFile(url: tempURL())
        try FileManager.default.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{pas du json".utf8).write(to: file.url)
        expect(file.read() == nil)
        var future = sample
        future.version = Backstage.currentVersion + 1
        try file.write(future)
        expect(file.read() == nil)
        try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent())
    },
    Test("chemin par defaut : RIDEAU_STATE_PATH, sinon Application Support/Rideau/scene.json") {
        expectEqual(BackstageFile.defaultURL(environment: ["RIDEAU_STATE_PATH": "/tmp/x.json"]).path, "/tmp/x.json")
        let url = BackstageFile.defaultURL(environment: [:])
        expect(url.path.hasSuffix("Application Support/Rideau/scene.json"), url.path)
    },
]
