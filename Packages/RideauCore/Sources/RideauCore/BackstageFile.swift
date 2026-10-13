import Foundation

/// Etat sauvegarde du rideau baisse (JSON, ecriture atomique) : sa presence au lancement signale un rideau
/// reste baisse (plantage, arret force) et permet de tout lever a l'identique.
public struct BackstageFile: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    /// `RIDEAU_STATE_PATH` (mode capture, essais), sinon `~/Library/Application Support/Rideau/scene.json`.
    public static func defaultURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let path = environment["RIDEAU_STATE_PATH"], !path.isEmpty { return URL(fileURLWithPath: path) }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Rideau", isDirectory: true).appendingPathComponent("scene.json")
    }

    /// Etat sauvegarde, ou nil (absent, illisible, ou ecrit par une version plus recente).
    public func read() -> Backstage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backstage = try? decoder.decode(Backstage.self, from: data),
              backstage.version <= Backstage.currentVersion else { return nil }
        return backstage
    }

    public func write(_ backstage: Backstage) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(backstage).write(to: url, options: .atomic)
    }

    public func erase() {
        try? FileManager.default.removeItem(at: url)
    }
}
