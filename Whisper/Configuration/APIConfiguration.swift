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

    let openAIKey: String?
    let openAIModel: String
    let elevenLabsKey: String?
    let elevenLabsVoiceID: String?
    /// Optional; defaults to `ElevenLabsVoiceService.defaultModelID`.
    let elevenLabsModelID: String?

    static func load(from bundle: Bundle = .main) -> APIConfiguration {
        APIConfiguration(
            openAIKey: value(for: "OPENAI_API_KEY", in: bundle),
            openAIModel: value(for: "OPENAI_MODEL", in: bundle) ?? defaultOpenAIModel,
            elevenLabsKey: value(for: "ELEVENLABS_API_KEY", in: bundle),
            elevenLabsVoiceID: value(for: "ELEVENLABS_VOICE_ID", in: bundle),
            elevenLabsModelID: value(for: "ELEVENLABS_MODEL_ID", in: bundle)
        )
    }

    private static func value(for key: String, in bundle: Bundle) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        // Tolerate stray quotes or spaces pasted around a value in Secrets.xcconfig.
        let trimmed = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”")))
        // Unset build settings arrive empty (or unexpanded); treat obvious placeholders as missing too.
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("$("),
              !trimmed.lowercased().hasPrefix("your") else { return nil }
        return trimmed
    }
}
