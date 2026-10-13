import Foundation

public enum CurtainState: Equatable, Sendable {
    case raised, lowering, lowered, raising

    /// Baisse ou en train de baisser : les apps sont (ou vont etre) en coulisses.
    public var isDown: Bool { self == .lowered || self == .lowering }
}

public enum CurtainCommand: Equatable, Sendable {
    case lower, raise
}

/// Etats du rideau. Un appui (raccourci, menu, URL) donne une commande, ou rien : pendant une transition,
/// ou moins de 250 ms apres l'appui precedent (rebond, double appui).
public struct CurtainMachine: Sendable {
    public static let debounce: TimeInterval = 0.25

    public private(set) var state: CurtainState
    /// Rideau retrouve baisse au lancement (etat sauvegarde) : a lever.
    public private(set) var recovered: Bool
    private var lastPress: Date?

    public init(recovering: Bool = false) {
        state = recovering ? .lowered : .raised
        recovered = recovering
    }

    /// Bascule : baisser si leve, lever si baisse.
    public mutating func toggle(now: Date) -> CurtainCommand? {
        if let lastPress, now.timeIntervalSince(lastPress) < Self.debounce { return nil }
        switch state {
        case .raised: return begin(.lower, now: now)
        case .lowered: return begin(.raise, now: now)
        case .lowering, .raising: return nil
        }
    }

    /// Demande explicite (baisser, lever) : idempotente.
    public mutating func request(_ command: CurtainCommand, now: Date) -> CurtainCommand? {
        switch (command, state) {
        case (.lower, .raised), (.raise, .lowered): return begin(command, now: now)
        default: return nil
        }
    }

    /// Fin de la transition en cours.
    public mutating func finish() {
        switch state {
        case .lowering: state = .lowered
        case .raising:
            state = .raised
            recovered = false
        case .raised, .lowered: break
        }
    }

    /// Transition abandonnee : on revient a l'etat de depart.
    public mutating func fail() {
        switch state {
        case .lowering: state = .raised
        case .raising: state = .lowered
        case .raised, .lowered: break
        }
    }

    private mutating func begin(_ command: CurtainCommand, now: Date) -> CurtainCommand {
        lastPress = now
        state = command == .lower ? .lowering : .raising
        return command
    }
}
