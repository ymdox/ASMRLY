import Foundation
import OSLog

/// Tries the primary companion (OpenAI) and, if that call fails (rate limit, quota, network),
/// answers with the fallback (pre-written lines) so Luna never goes silent mid-conversation.
/// The failure reason is logged; offline errors are still surfaced so the UI can say so.
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
            Self.logger.error("Primary companion failed (\(String(describing: error), privacy: .public)); using a pre-written line.")
            return try await fallback.reply(to: userText, history: history, context: context)
        }
    }
}
