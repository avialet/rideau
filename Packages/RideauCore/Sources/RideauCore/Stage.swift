import Foundation

/// Une app en cours d'execution, vue au moment de baisser ou de lever le rideau.
public struct AppSnapshot: Codable, Equatable, Sendable {
    public var pid: Int32
    public var bundleID: String?
    public var name: String
    /// Masquee (Cmd-H ou par Rideau).
    public var isHidden: Bool
    /// App ordinaire, avec Dock et menus (`activationPolicy == .regular`).
    public var isRegular: Bool
    /// Une fenetre aux dimensions d'un ecran : la masquer fermerait son Space.
    public var isFullScreen: Bool
    /// Rang de sa premiere fenetre visible, de l'avant (0) vers l'arriere ; nil sans fenetre a l'ecran.
    public var rank: Int?

    public init(pid: Int32, bundleID: String?, name: String, isHidden: Bool, isRegular: Bool,
                isFullScreen: Bool = false, rank: Int? = nil) {
        self.pid = pid
        self.bundleID = bundleID
        self.name = name
        self.isHidden = isHidden
        self.isRegular = isRegular
        self.isFullScreen = isFullScreen
        self.rank = rank
    }

    /// Meme instance : meme pid et meme bundle (un pid reutilise par une autre app ne compte pas).
    public func isSameInstance(as other: AppSnapshot) -> Bool {
        pid == other.pid && bundleID == other.bundleID
    }
}

/// Ce que le rideau laisse en scene.
public struct CurtainPolicy: Equatable, Sendable {
    /// Garder l'app au premier plan (defaut) : rien a reactiver en levant le rideau.
    public var keepFrontmost: Bool
    /// Bundles jamais masques (les visios par defaut).
    public var alwaysVisible: Set<String>
    /// Laisser les apps en plein ecran telles quelles (defaut).
    public var keepFullScreen: Bool
    /// Pid de Rideau lui-meme.
    public var ownPID: Int32

    public init(keepFrontmost: Bool = true, alwaysVisible: Set<String> = CurtainPolicy.defaultAlwaysVisible,
                keepFullScreen: Bool = true, ownPID: Int32) {
        self.keepFrontmost = keepFrontmost
        self.alwaysVisible = alwaysVisible
        self.keepFullScreen = keepFullScreen
        self.ownPID = ownPID
    }

    /// Jamais masques, quoi qu'on regle : Rideau et Vialet.
    public static let neverHidden: Set<String> = ["fr.vialet.rideau", "fr.vialet.vialet"]

    /// Apps de visio connues, avec leur nom : toujours visibles par defaut (on presente depuis elles).
    /// Les messageries (Slack, Discord) n'y sont pas : leurs conversations sont ce qu'on veut cacher.
    public static let videoApps: [(id: String, name: String)] = [
        ("us.zoom.xos", "Zoom"),
        ("com.microsoft.teams2", "Microsoft Teams"),
        ("com.microsoft.teams", "Microsoft Teams (classique)"),
        ("Cisco-Systems.Spark", "Webex"),
        ("com.cisco.webexmeetingsapp", "Webex Meetings"),
        ("com.apple.FaceTime", "FaceTime"),
    ]

    public static let defaultAlwaysVisible: Set<String> = Set(videoApps.map(\.id))

    /// Nom connu d'un bundle de la liste des visios.
    public static func knownName(_ bundleID: String) -> String? {
        videoApps.first { $0.id == bundleID }?.name
    }
}

/// Ce que Rideau a mis en coulisses : de quoi tout remettre a l'identique, meme apres un plantage.
public struct Backstage: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var loweredAt: Date
    /// App au premier plan quand le rideau est tombe.
    public var frontmost: AppSnapshot?
    /// Apps masquees par Rideau, de l'avant vers l'arriere. Seules celles-ci seront reaffichees.
    public var hidden: [AppSnapshot]
    /// Apps qui ont refuse d'etre masquees (noms).
    public var refused: [String]

    public init(loweredAt: Date, frontmost: AppSnapshot?, hidden: [AppSnapshot], refused: [String] = []) {
        self.version = Backstage.currentVersion
        self.loweredAt = loweredAt
        self.frontmost = frontmost
        self.hidden = hidden
        self.refused = refused
    }

    /// L'utilisateur a reaffiche cette app lui-meme : elle ne nous appartient plus (s'il la masque a
    /// nouveau, c'est son choix, on ne la reaffichera pas).
    public func releasing(pid: Int32) -> Backstage {
        var copy = self
        copy.hidden.removeAll { $0.pid == pid }
        return copy
    }

    /// Apps restees visibles malgre la demande : retirees (on ne les reaffichera pas), noms retenus.
    public func refusing(_ apps: [AppSnapshot]) -> Backstage {
        guard !apps.isEmpty else { return self }
        var copy = self
        copy.hidden.removeAll { hidden in apps.contains { $0.isSameInstance(as: hidden) } }
        copy.refused += apps.map(\.name)
        return copy
    }

    /// Ne garder que les apps effectivement masquees.
    public func keeping(pids: Set<Int32>) -> Backstage {
        var copy = self
        copy.hidden.removeAll { !pids.contains($0.pid) }
        return copy
    }
}

/// Restitution : apps a reafficher de l'arriere vers l'avant, puis app a reactiver.
public struct RaisePlan: Equatable, Sendable {
    public var unhide: [AppSnapshot]
    /// App du premier plan, a reactiver si Rideau l'avait masquee.
    public var activate: AppSnapshot?
    /// Apps quittees (ou relancees) depuis : rien a faire.
    public var gone: [AppSnapshot]

    public init(unhide: [AppSnapshot], activate: AppSnapshot?, gone: [AppSnapshot]) {
        self.unhide = unhide
        self.activate = activate
        self.gone = gone
    }

    /// App a reactiver, seulement si personne d'autre n'a pris la main entre-temps : l'app au premier plan
    /// est Rideau, aucune, ou une app que l'on reaffiche.
    public func activation(frontmostPID: Int32?, ownPID: Int32) -> AppSnapshot? {
        guard let activate else { return nil }
        guard let frontmostPID, frontmostPID != ownPID else { return activate }
        return unhide.contains { $0.pid == frontmostPID } ? activate : nil
    }
}

public enum Stage {
    /// Apps a masquer, de l'avant vers l'arriere (apps sans fenetre a l'ecran a la fin, par nom).
    public static func planLower(apps: [AppSnapshot], frontmostPID: Int32?, policy: CurtainPolicy) -> [AppSnapshot] {
        apps.filter { app in
            guard app.isRegular, !app.isHidden, app.pid != policy.ownPID else { return false }
            if let id = app.bundleID, CurtainPolicy.neverHidden.contains(id) || policy.alwaysVisible.contains(id) {
                return false
            }
            if policy.keepFrontmost, app.pid == frontmostPID { return false }
            if policy.keepFullScreen, app.isFullScreen { return false }
            return true
        }
        .sorted(by: frontToBack)
    }

    /// Restitution exacte : seulement les apps masquees par Rideau, encore la sous le meme pid, de l'arriere
    /// vers l'avant (apps sans rang d'abord : elles n'avaient rien a l'ecran). En levee normale, toutes : celles
    /// que l'utilisateur a reaffichees ont deja ete retirees (`releasing`), et une levee juste apres la baisse
    /// precede parfois le masquage (asynchrone). Apres un arret inattendu (`afterCrash`), rien n'a suivi
    /// l'utilisateur : seules les apps encore masquees reviennent.
    public static func planRaise(backstage: Backstage, running: [AppSnapshot], afterCrash: Bool) -> RaisePlan {
        var unhide: [AppSnapshot] = []
        var gone: [AppSnapshot] = []
        for app in backstage.hidden {
            guard let now = running.first(where: { $0.isSameInstance(as: app) }) else {
                gone.append(app)
                continue
            }
            if now.isHidden || !afterCrash { unhide.append(app) }
        }
        unhide.sort { !frontToBack($0, $1) }
        let activate = backstage.frontmost.flatMap { front in unhide.first { $0.isSameInstance(as: front) } }
        return RaisePlan(unhide: unhide, activate: activate, gone: gone)
    }

    /// Apps du rideau encore la et toujours visibles : `hide()` ne dit pas de facon fiable s'il a reussi
    /// (il peut rendre faux et masquer quand meme), on verifie donc l'etat reel un instant apres.
    public static func refusals(backstage: Backstage, running: [AppSnapshot]) -> [AppSnapshot] {
        backstage.hidden.filter { app in running.contains { $0.isSameInstance(as: app) && !$0.isHidden } }
    }

    /// Ordre de l'avant vers l'arriere : rang croissant, sans rang a la fin, puis nom et pid.
    static func frontToBack(_ a: AppSnapshot, _ b: AppSnapshot) -> Bool {
        switch (a.rank, b.rank) {
        case let (x?, y?) where x != y: return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        default:
            if a.name != b.name { return a.name.localizedStandardCompare(b.name) == .orderedAscending }
            return a.pid < b.pid
        }
    }
}
