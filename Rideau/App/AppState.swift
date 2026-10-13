import Foundation
import Observation
import RideauCore

/// Etat partage de l'app : ce que les vues observent.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    private init() {}
}
