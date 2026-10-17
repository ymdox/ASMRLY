import Foundation

/// Result of a live check against one provider, shown on Home in debug builds.
struct ProviderCheck: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let isWorking: Bool
    let detail: String
}

/// Makes one tiny real request to each configured provider, so configuration problems
/// (wrong or revoked key, no credits, unusable voice) are visible on screen instead of
/// only in the Xcode console. Debug builds only.
enum ConnectionDiagnostics {
    static func run(configuration: APIConfiguration, session: URLSession = .shared) async -> [ProviderCheck] {
        async let openAI = checkOpenAI(configuration, session: session)
        async let elevenLabs = checkElevenLabs(configuration, session: session)
        return await [openAI, elevenLabs]
    }

    private static func checkOpenAI(_ configuration: APIConfiguration, session: URLSession) async -> ProviderCheck {
        let name = "OpenAI (Luna's words)"
        guard let key = configuration.openAIKey else {
            return ProviderCheck(name: name, isWorking: false, detail: "No OPENAI_API_KEY found, so Luna uses pre-written lines.")
        }
        guard let url = URL(string: configuration.openAIBaseURL + "/v1/chat/completions") else {
            return ProviderCheck(name: name, isWorking: false, detail: "Invalid URL.")
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": configuration.openAIModel,
            "max_completion_tokens": 5,
            "messages": [["role": "user", "content": "Say hi."]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let suffix = "Model \(configuration.openAIModel) · key …\(key.suffix(4))"
        return await perform(request, name: name, session: session, success: "Connected. \(suffix)", context: suffix)
    }

    private static func checkElevenLabs(_ configuration: APIConfiguration, session: URLSession) async -> ProviderCheck {
        let name = "ElevenLabs (Luna's voice)"
        guard let key = configuration.elevenLabsKey else {
            return ProviderCheck(name: name, isWorking: false, detail: "No ELEVENLABS_API_KEY found, so Luna uses the Apple voice.")
        }
        guard let voiceID = configuration.elevenLabsVoiceID else {
            return ProviderCheck(name: name, isWorking: false, detail: "No ELEVENLABS_VOICE_ID found, so Luna uses the Apple voice.")
        }
        let model = configuration.elevenLabsModelID ?? ElevenLabsVoiceService.defaultModelID
        guard let encodedVoice = voiceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(encodedVoice)?output_format=mp3_44100_128") else {
            return ProviderCheck(name: name, isWorking: false, detail: "Invalid voice ID.")
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        let body: [String: Any] = ["text": "Hi.", "model_id": model]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let suffix = "Model \(model) · voice \(voiceID) · key …\(key.suffix(4))"
        return await perform(request, name: name, session: session, success: "Connected. \(suffix)", context: suffix)
    }

    private static func perform(
        _ request: URLRequest,
        name: String,
        session: URLSession,
        success: String,
        context: String
    ) async -> ProviderCheck {
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if (200..<300).contains(status) {
                return ProviderCheck(name: name, isWorking: true, detail: success)
            }
            return ProviderCheck(name: name, isWorking: false, detail: "HTTP \(status): \(errorMessage(from: data)) · \(context)")
        } catch {
            return ProviderCheck(name: name, isWorking: false, detail: "Can't reach the server: \(error.localizedDescription)")
        }
    }

    /// Pulls the human-readable message out of OpenAI / ElevenLabs error bodies.
    static func errorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
                return message
            }
            if let detail = object["detail"] as? [String: Any], let message = detail["message"] as? String {
                return message
            }
            if let detail = object["detail"] as? [[String: Any]], let message = detail.first?["msg"] as? String {
                return message
            }
            if let detail = object["detail"] as? String {
                return detail
            }
        }
        return String(decoding: data.prefix(200), as: UTF8.self)
    }
}
