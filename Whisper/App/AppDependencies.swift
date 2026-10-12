import Foundation

/// The set of services a session runs on. Real providers are used when keys are present;
/// otherwise the mock companion and the on-device Apple voice take over.
@MainActor
struct AppDependencies {
    let audio: AudioEngineService
    let ai: any AIConversationService
    let speech: any SpeechRecognitionService
    let voice: any VoiceSynthesisService

    static func live(configuration: APIConfiguration = .load()) -> AppDependencies {
        let audio = AudioEngineService()
        let appleVoice = AppleVoiceSynthesisService(audio: audio)

        let voice: any VoiceSynthesisService
        if let key = configuration.elevenLabsKey, let voiceID = configuration.elevenLabsVoiceID {
            voice = FallbackVoiceService(
                primary: ElevenLabsVoiceService(apiKey: key, voiceID: voiceID, audio: audio),
                fallback: appleVoice
            )
        } else {
            voice = appleVoice
        }

        let ai: any AIConversationService
        if let key = configuration.openAIKey {
            ai = OpenAIConversationService(apiKey: key, model: configuration.openAIModel)
        } else {
            ai = MockAIConversationService()
        }

        return AppDependencies(
            audio: audio,
            ai: ai,
            speech: AppleSpeechRecognitionService(),
            voice: voice
        )
    }
}
