import Foundation
import OSLog

/// Tries the primary companion (OpenAI) and, if that call fails (rate limit, quota, network),
/// answers with the fallback (pre-written lines) so Luna never goes silent mid-conversation.
/// The failure reason is logged; offline errors are still surfaced so the UI can say so.
extension Notification.Name {
    /// Posted when the primary companion failed and a pre-written line was used. userInfo["reason"]: String.
    static let companionFellBack = Notification.Name("WhisperCompanionFellBack")
}

struct FallbackAIConversationService: AIConversationService {
    let primary: any AIConversationService
    let fallback: any AIConversationService

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Whisper", category: "Companion")

    func reply(to userText: String?, history: [ChatMessage], context: ConversationContext) async throws -> String {
        do {
            return try await primary.reply(to: userText, history: history, context: context)
        } catch {
            try Task.checkCancellation()
            if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                throw error
            }
            let reason = (error as? URLError)?.localizedDescription ?? String(describing: error)
            Self.logger.error("Primary companion failed (\(reason, privacy: .public)); using a pre-written line.")
            NotificationCenter.default.post(name: .companionFellBack, object: nil, userInfo: ["reason": reason])
            return try await fallback.reply(to: userText, history: history, context: context)
        }
    }
}
