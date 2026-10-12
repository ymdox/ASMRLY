import Foundation

/// The set of services a session runs on. Swap implementations here.
@MainActor
struct AppDependencies {
    let audio: AudioEngineService
    let ai: any AIConversationService
    let speech: any SpeechRecognitionService
    let voice: any VoiceSynthesisService

    static func live() -> AppDependencies {
        let audio = AudioEngineService()
        return AppDependencies(
            audio: audio,
            ai: MockAIConversationService(),
            speech: AppleSpeechRecognitionService(),
            voice: AppleVoiceSynthesisService(audio: audio)
        )
    }
}
