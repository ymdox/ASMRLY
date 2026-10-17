import Foundation

struct ChatMessage: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    let role: Role
    let content: String
}

enum ConversationStage: Sendable {
    case conversation
    case relaxation
}

/// Which kind of line the companion should produce.
enum ConversationMoment: Sendable {
    /// A normal turn: a reply to the user, or a continuation when they're quiet.
    case turn
    /// The greeting at the start of the session.
    case opening
    /// The soft goodnight before the session continues with ambience only.
    case closing
}

struct ConversationContext: Sendable {
    let companionName: String
    let stage: ConversationStage
    /// 0…1 progress through the current stage.
    let stageProgress: Double
    /// True when the companion continues on its own (Just Listen / relaxation).
    let isMonologue: Bool
    /// Talk mode and the user has been quiet: the companion may softly invite them to share.
    var invitesReply: Bool = false
    var moment: ConversationMoment = .turn
}

protocol AIConversationService: Sendable {
    /// Returns the companion's next line. `userText` is nil when the companion continues a monologue.
    func reply(to userText: String?, history: [ChatMessage], context: ConversationContext) async throws -> String
}
