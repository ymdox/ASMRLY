import Foundation
import OSLog

enum AIServiceError: Error, CustomStringConvertible {
    case invalidRequest
    case badResponse(statusCode: Int, message: String)
    case emptyResponse

    var description: String {
        switch self {
        case .invalidRequest: "Invalid request"
        case .badResponse(let status, let message): "HTTP \(status): \(message)"
        case .emptyResponse: "Empty reply"
        }
    }
}

/// Chat Completions-backed companion.
struct OpenAIConversationService: AIConversationService {
    let apiKey: String
    let model: String
    var baseURL: String = APIConfiguration.defaultOpenAIBaseURL
    var session: URLSession = .shared

    private static let historyLimit = 8
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Whisper", category: "OpenAI")

    func reply(to userText: String?, history: [ChatMessage], context: ConversationContext) async throws -> String {
        guard let url = URL(string: baseURL + "/v1/chat/completions") else { throw AIServiceError.invalidRequest }

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

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.badResponse(statusCode: -1, message: "No HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            // OpenAI explains failures (invalid key, no credits / insufficient_quota, unknown model) in the body.
            let detail = String(decoding: data.prefix(500), as: UTF8.self)
            // (Logged in full; the thrown error carries OpenAI's own message for the UI.)
            Self.logger.error("HTTP \(http.statusCode, privacy: .public) for model \(model, privacy: .public): \(detail, privacy: .public)")
            throw AIServiceError.badResponse(statusCode: http.statusCode, message: ConnectionDiagnostics.errorMessage(from: data))
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        Self.logger.info("Reply received from \(model, privacy: .public).")
        guard let content = decoded.choices.first?.message.content,
              let text = CompanionPrompt.sanitize(content) else {
            Self.logger.error("Empty reply from \(model, privacy: .public).")
            throw AIServiceError.emptyResponse
        }
        return text
    }

    /// Sends the request, retrying once after a short pause if the network hiccups
    /// (timeout, dropped connection) so a flaky connection doesn't cost Luna a line.
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url?.absoluteString ?? "?"
        var attempt = 1
        while true {
            Self.logger.info("Sending request to \(url, privacy: .public) (model \(model, privacy: .public), attempt \(attempt, privacy: .public)).")
            do {
                return try await session.data(for: request)
            } catch let error as URLError where attempt == 1 && Self.isTransient(error) {
                Self.logger.error("Request failed (\(error.localizedDescription, privacy: .public)); retrying once.")
                attempt += 1
                try await Task.sleep(for: .milliseconds(600))
            } catch {
                Self.logger.error("Request failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
    }

    private static func isTransient(_ error: URLError) -> Bool {
        [.timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet]
            .contains(error.code)
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
