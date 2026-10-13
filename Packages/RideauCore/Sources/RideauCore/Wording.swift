/// Phrases de la pastille et de la Scene.
public enum Wording {
    public static func backstage(_ count: Int) -> String {
        count == 0 ? "Aucune app en coulisses" : "\(count) \(apps(count)) en coulisses"
    }

    public static func returned(_ count: Int) -> String {
        count == 0 ? "Rien \u{00E0} r\u{00E9}afficher" : "\(count) \(apps(count)) de retour"
    }

    public static func preview(_ count: Int) -> String {
        switch count {
        case 0: "Rien \u{00E0} masquer pour l\u{2019}instant"
        case 1: "1 app passera en coulisses"
        default: "\(count) apps passeront en coulisses"
        }
    }

    private static func apps(_ count: Int) -> String { count > 1 ? "apps" : "app" }
}
