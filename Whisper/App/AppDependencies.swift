import Foundation

/// The set of services a session runs on. Swap implementations here.
@MainActor
struct AppDependencies {
    let audio: AudioEngineService
    let ai: any AIConversationService
    let speech: any SpeechRecognitionService
    let voice: any VoiceSynthesisService

    static func live() -> AppDependencies {
        AppDependencies(
            audio: AudioEngineService(),
            ai: MockAIConversationService(),
            speech: UnavailableSpeechRecognitionService(),
            voice: SilentVoiceService()
        )
    }
}
