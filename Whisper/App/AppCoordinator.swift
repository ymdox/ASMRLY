import Foundation
import Observation

/// Top-level flow: Home → (permission primer) → live session.
@MainActor
@Observable
final class AppCoordinator {
    let companion = Companion.luna
    var activeSession: SessionManager?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies? = nil) {
        self.dependencies = dependencies ?? .live()
    }

    func start(ambience: Ambience) {
        guard activeSession == nil else { return }
        let canTalk = dependencies.speech.isAvailable
        activeSession = SessionManager(
            companion: companion,
            ambience: ambience,
            configuration: .standard,
            mode: canTalk ? .talk : .justListen,
            canTalk: canTalk,
            dependencies: dependencies
        )
    }

    func closeSession() {
        activeSession = nil
    }
}
