import Foundation

struct SessionConfiguration: Sendable {
    /// The one knob for session length. Phases are derived from it (5 / 10 / 5 min for 20).
    static let defaultTotalMinutes: Double = 20

    /// Default configuration. For quick testing, pass a launch argument such as
    /// `-WhisperSessionMinutes 2` in the scheme to shorten every session.
    static var standard: SessionConfiguration {
        let override = UserDefaults.standard.double(forKey: "WhisperSessionMinutes")
        return SessionConfiguration(totalMinutes: override > 0 ? override : defaultTotalMinutes)
    }

    let conversationDuration: TimeInterval
    let relaxationDuration: TimeInterval
    let ambientDuration: TimeInterval

    var totalDuration: TimeInterval {
        conversationDuration + relaxationDuration + ambientDuration
    }

    /// Splits a total length into 25% conversation, 50% relaxation and 25% ambience.
    init(totalMinutes: Double) {
        let total = max(totalMinutes, 1) * 60
        conversationDuration = total * 0.25
        relaxationDuration = total * 0.5
        ambientDuration = total * 0.25
    }

    init(conversation: TimeInterval, relaxation: TimeInterval, ambient: TimeInterval) {
        conversationDuration = conversation
        relaxationDuration = relaxation
        ambientDuration = ambient
    }

    func phase(at elapsed: TimeInterval) -> SessionPhase {
        if elapsed < conversationDuration { return .conversation }
        if elapsed < conversationDuration + relaxationDuration { return .relaxation }
        if elapsed < totalDuration { return .ambientOnly }
        return .completed
    }

    /// Length of the slow fade at the very end of the ambient phase.
    var finalFadeDuration: TimeInterval {
        min(30, max(ambientDuration * 0.5, 4))
    }

    // Fades — audio is never cut abruptly (always ≥ 2 s).
    static let ambienceFadeIn: TimeInterval = 5
    static let voiceFade: TimeInterval = 2
    static let pauseFade: TimeInterval = 3
    static let endFade: TimeInterval = 3

    /// How long a transcript line stays on screen before fading away.
    static let transcriptLinger: TimeInterval = 10
}
