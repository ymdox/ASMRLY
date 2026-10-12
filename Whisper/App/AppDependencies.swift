import Foundation
import OSLog

/// The set of services a session runs on. Real providers are used when keys are present;
/// otherwise the mock companion and the on-device Apple voice take over.
@MainActor
struct AppDependencies {
    let audio: AudioEngineService
    let ai: any AIConversationService
    let speech: any SpeechRecognitionService
    let voice: any VoiceSynthesisService
    let permissions: PermissionsService
    let safety: SafetyService

    static func live(configuration: APIConfiguration = .load()) -> AppDependencies {
        let audio = AudioEngineService()
        let appleVoice = AppleVoiceSynthesisService(audio: audio)

        let voice: any VoiceSynthesisService
        if let key = configuration.elevenLabsKey, let voiceID = configuration.elevenLabsVoiceID {
            voice = FallbackVoiceService(
                primary: ElevenLabsVoiceService(
                    apiKey: key,
                    voiceID: voiceID,
                    modelID: configuration.elevenLabsModelID,
                    audio: audio
                ),
                fallback: appleVoice
            )
        } else {
            voice = appleVoice
        }

        let ai: any AIConversationService
        if let key = configuration.openAIKey {
            ai = FallbackAIConversationService(
                primary: OpenAIConversationService(apiKey: key, model: configuration.openAIModel),
                fallback: MockAIConversationService(delay: 0...0.2)
            )
        } else {
            ai = MockAIConversationService()
        }

        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Whisper", category: "Setup")
        let voiceName = configuration.elevenLabsKey != nil && configuration.elevenLabsVoiceID != nil
            ? "ElevenLabs (\(configuration.elevenLabsModelID ?? ElevenLabsVoiceService.defaultModelID)) with Apple fallback"
            : "Apple (no ElevenLabs key or voice ID)"
        let aiName = configuration.openAIKey != nil ? "OpenAI (\(configuration.openAIModel))" : "Mock (no OpenAI key)"
        logger.info("Voice: \(voiceName, privacy: .public) · Companion: \(aiName, privacy: .public)")

        return AppDependencies(
            audio: audio,
            ai: ai,
            speech: AppleSpeechRecognitionService(),
            voice: voice,
            permissions: PermissionsService(),
            safety: SafetyService()
        )
    }

    /// Offline, silent dependencies for SwiftUI previews.
    static func preview() -> AppDependencies {
        AppDependencies(
            audio: AudioEngineService(),
            ai: MockAIConversationService(),
            speech: UnavailableSpeechRecognitionService(),
            voice: SilentVoiceService(),
            permissions: PermissionsService(),
            safety: SafetyService()
        )
    }
}
