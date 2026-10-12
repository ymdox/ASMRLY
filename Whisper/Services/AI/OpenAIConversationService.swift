import Foundation
import OSLog

enum AIServiceError: Error {
    case invalidRequest
    case badResponse(statusCode: Int)
    case emptyResponse
}

/// Chat Completions-backed companion.
struct OpenAIConversationService: AIConversationService {
    let apiKey: String
    let model: String
    var session: URLSession = .shared

    private static let endpoint = "https://api.openai.com/v1/chat/completions"
    private static let historyLimit = 8
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Whisper", category: "OpenAI")

    func reply(to userText: String?, history: [ChatMessage], context: ConversationContext) async throws -> String {
        guard let url = URL(string: Self.endpoint) else { throw AIServiceError.invalidRequest }

        var messages = [ChatMessage(role: .system, content: CompanionPrompt.system(for: context))]
        messages += history.suffix(Self.historyLimit)
        messages.append(ChatMessage(role: .user, content: userText ?? CompanionPrompt.continuePrompt))

        let body = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: Self.supportsTemperature(model) ? 0.8 : nil,
            maxCompletionTokens: 120
        )

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            Self.logger.error("Request failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.badResponse(statusCode: -1) }
        guard (200..<300).contains(http.statusCode) else {
            // OpenAI explains failures (invalid key, no credits / insufficient_quota, unknown model) in the body.
            let detail = String(decoding: data.prefix(500), as: UTF8.self)
            Self.logger.error("HTTP \(http.statusCode, privacy: .public) for model \(model, privacy: .public): \(detail, privacy: .public)")
            throw AIServiceError.badResponse(statusCode: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              let text = CompanionPrompt.sanitize(content) else {
            Self.logger.error("Empty reply from \(model, privacy: .public).")
            throw AIServiceError.emptyResponse
        }
        return text
    }

    /// Reasoning models only accept the default temperature.
    private static func supportsTemperature(_ model: String) -> Bool {
        !(model.hasPrefix("o") || model.hasPrefix("gpt-5"))
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxCompletionTokens: Int
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}
