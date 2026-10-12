import Foundation

/// Tries the primary voice (e.g. ElevenLabs) and falls back to a secondary one (Apple) for that line
/// if it fails, so a network hiccup never leaves the companion silent.
@MainActor
final class FallbackVoiceService: VoiceSynthesisService {
    private let primary: any VoiceSynthesisService
    private let fallback: any VoiceSynthesisService

    init(primary: any VoiceSynthesisService, fallback: any VoiceSynthesisService) {
        self.primary = primary
        self.fallback = fallback
    }

    func speak(_ text: String, style: VoiceStyle) async throws {
        do {
            try await primary.speak(text, style: style)
        } catch {
            try Task.checkCancellation()
            try await fallback.speak(text, style: style)
        }
    }

    func stop(fade: TimeInterval) async {
        // Both share the engine's voice chain, so one fade covers both.
        await fallback.stop(fade: fade)
        await primary.stop(fade: fade)
    }
}
