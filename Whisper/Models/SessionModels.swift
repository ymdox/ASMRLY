import Foundation

/// Timeline of a session: Preparing → Conversation → Relaxation → AmbientOnly → Completed,
/// plus Paused and Error.
enum SessionPhase: Equatable, Sendable {
    case preparing
    case conversation
    case relaxation
    case ambientOnly
    case completed
    case paused
    case error

    /// The session clock advances in these phases.
    var isRunning: Bool {
        self == .conversation || self == .relaxation || self == .ambientOnly
    }

    /// The companion may speak (and be spoken to) in these phases.
    var allowsVoice: Bool {
        self == .conversation || self == .relaxation
    }
}

/// What the companion is doing right now.
enum CompanionActivity: Equatable, Sendable {
    case idle
    case listening
    case thinking
    case whispering
}

enum InteractionMode: String, CaseIterable, Identifiable, Sendable {
    case talk
    case justListen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .talk: "Talk"
        case .justListen: "Just Listen"
        }
    }
}

struct TranscriptLine: Identifiable, Equatable, Sendable {
    enum Speaker: Sendable {
        case user
        case companion
    }

    let id = UUID()
    let speaker: Speaker
    let text: String
}
