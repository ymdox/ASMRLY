import Foundation

/// Optional API keys, read from Info.plist (which is populated from Config/Secrets.xcconfig).
///
/// Any missing key falls back automatically: no OpenAI key → mock companion,
/// no ElevenLabs key/voice → on-device Apple voice. The app works with zero keys.
///
/// IMPORTANT: for production, keys must not ship inside the app binary. Route these calls
/// through a backend you control. Embedding them here is acceptable only for this MVP.
struct APIConfiguration: Sendable {
    static let defaultOpenAIModel = "gpt-4o-mini"
    static let defaultOpenAIBaseURL = "https://api.openai.com"

    var openAIKey: String?
    let openAIModel: String
    /// Scheme + host of the OpenAI-compatible API. Only overridden by automated tests.
    var openAIBaseURL: String = APIConfiguration.defaultOpenAIBaseURL
    let elevenLabsKey: String?
    let elevenLabsVoiceID: String?
    /// Optional; defaults to `ElevenLabsVoiceService.defaultModelID`.
    let elevenLabsModelID: String?

    static func load(from bundle: Bundle = .main) -> APIConfiguration {
        var configuration = APIConfiguration(
            openAIKey: value(for: "OPENAI_API_KEY", in: bundle),
            openAIModel: value(for: "OPENAI_MODEL", in: bundle) ?? defaultOpenAIModel,
            elevenLabsKey: value(for: "ELEVENLABS_API_KEY", in: bundle),
            elevenLabsVoiceID: value(for: "ELEVENLABS_VOICE_ID", in: bundle),
            elevenLabsModelID: value(for: "ELEVENLABS_MODEL_ID", in: bundle)
        )
        #if DEBUG
        // Automated simulator tests point the app at a local fake OpenAI server:
        // -WhisperOpenAIBaseURL http://127.0.0.1:8099 -WhisperOpenAIKeyOverride test
        let defaults = UserDefaults.standard
        if let baseURL = defaults.string(forKey: "WhisperOpenAIBaseURL"), !baseURL.isEmpty {
            configuration.openAIBaseURL = baseURL
        }
        if let key = defaults.string(forKey: "WhisperOpenAIKeyOverride"), !key.isEmpty {
            configuration.openAIKey = key
        }
        #endif
        return configuration
    }

    private static func value(for key: String, in bundle: Bundle) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        // Tolerate stray quotes or spaces pasted around a value in Secrets.xcconfig.
        let trimmed = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”")))
        // Unset build settings arrive empty (or unexpanded); treat obvious placeholders as missing too.
        // "Bearer " belongs in the HTTP header, which the app adds itself; drop it if pasted here.
        var value = trimmed
        if value.lowercased().hasPrefix("bearer ") {
            value = String(value.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespaces)
        }
        guard !value.isEmpty,
              !value.hasPrefix("$("),
              !value.lowercased().hasPrefix("your") else { return nil }
        return value
    }
}
