import Foundation

/// Offline companion with pre-written calm lines. Used whenever no OpenAI key is configured.
struct MockAIConversationService: AIConversationService {
    var delay: ClosedRange<Double> = 0.8...1.6

    func reply(to userText: String?, history: [ChatMessage], context: ConversationContext) async throws -> String {
        try await Task.sleep(for: .seconds(Double.random(in: delay)))

        let pool: [String]
        switch (context.stage, userText) {
        case (.relaxation, _): pool = Self.relaxation
        case (.conversation, .some): pool = Self.responses
        case (.conversation, .none): pool = context.invitesReply ? Self.monologue + Self.invitations : Self.monologue
        }

        let recent = Set(history.suffix(8).filter { $0.role == .assistant }.map(\.content))
        let fresh = pool.filter { !recent.contains($0) }
        return fresh.randomElement() ?? pool.randomElement() ?? "Breathe in… and slowly let it go."
    }

    static let responses = [
        "That sounds like a lot… I'm glad you're here now.",
        "You don't have to solve anything right now… just be here with me.",
        "Mm… thank you for telling me. Let's set that down for a little while.",
        "It makes sense you'd feel that way… you've been carrying so much today.",
        "I hear you… there's nothing you need to do right now.",
        "That's okay… whatever today was, it's over now. You're allowed to rest.",
        "Let your shoulders soften as you breathe out… I'm right here.",
        "You're doing so well… just letting the day melt away.",
    ]

    static let monologue = [
        "Let your shoulders soften… there's nowhere else you need to be.",
        "Notice the sound around you… soft and steady… holding you.",
        "Breathe in slowly… and let it drift out… like a sigh.",
        "Your jaw can loosen now… your hands can rest.",
        "Imagine a warm blanket settling over you… heavy and safe.",
        "Every breath out takes a little more of the day away.",
        "You don't have to hold on to anything right now.",
        "Let your thoughts float by… like clouds on a quiet night.",
    ]

    static let invitations = [
        "If something's on your mind, you can tell me… or we can simply rest.",
        "I'm here if you'd like to talk… there's no hurry at all.",
        "How is your body feeling right now… heavy, or still a little tense?",
    ]

    static let relaxation = [
        "Breathe out… slowly.",
        "Soft shoulders… heavy arms.",
        "Let your eyes feel heavy.",
        "Just rest… I'm here.",
        "Sinking a little deeper…",
        "Nothing to do… nowhere to be.",
        "Warm… and safe… and still.",
        "Let the sound carry you.",
        "Slower… and softer…",
    ]
}
