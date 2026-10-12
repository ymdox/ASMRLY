import Foundation
import Observation

/// Top-level flow: Home → (microphone primer) → live session.
@MainActor
@Observable
final class AppCoordinator {
    let companion = Companion.luna
    var activeSession: SessionManager?
    var isShowingPermissionPrimer = false

    @ObservationIgnored private let dependencies: AppDependencies
    @ObservationIgnored private var pendingAmbience: Ambience?
    @ObservationIgnored private var wantsMicrophone = false

    init(dependencies: AppDependencies? = nil) {
        self.dependencies = dependencies ?? .live()
    }

    func start(ambience: Ambience) {
        guard activeSession == nil, pendingAmbience == nil else { return }
        if dependencies.permissions.needsPrompt {
            pendingAmbience = ambience
            wantsMicrophone = false
            isShowingPermissionPrimer = true
        } else {
            launch(ambience: ambience)
        }
    }

    func primerContinue() {
        wantsMicrophone = true
        isShowingPermissionPrimer = false
    }

    func primerNotNow() {
        wantsMicrophone = false
        isShowingPermissionPrimer = false
    }

    /// Runs after the primer sheet is fully dismissed (also when swiped away = "not now"),
    /// so the system prompt and the session cover never collide with the sheet animation.
    func primerDismissed() {
        guard let ambience = pendingAmbience else { return }
        let shouldRequest = wantsMicrophone
        Task {
            if shouldRequest {
                await dependencies.permissions.requestAccess()
            }
            pendingAmbience = nil
            launch(ambience: ambience)
        }
    }

    func closeSession() {
        activeSession = nil
    }

    #if DEBUG
    /// Test hook for automated simulator runs: launch with `-WhisperAutoStartAmbience rain`
    /// to skip Home and the primer and go straight into a session. Not compiled into Release.
    func autoStartIfRequested() {
        guard activeSession == nil,
              let raw = UserDefaults.standard.string(forKey: "WhisperAutoStartAmbience"),
              let ambience = Ambience(rawValue: raw) else { return }
        launch(ambience: ambience)
    }
    #endif

    private func launch(ambience: Ambience) {
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
}
