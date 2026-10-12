import Foundation

/// Tries the primary voice (ElevenLabs) and falls back to a secondary one (Apple) for that line
/// if it fails, so a network hiccup never leaves the companion silent.
/// After several failures in a row (e.g. a wrong key or no credits) it stops trying the primary
/// voice, so each line doesn't wait on a request that will fail.
@MainActor
final class FallbackVoiceService: VoiceSynthesisService {
    private let primary: any VoiceSynthesisService
    private let fallback: any VoiceSynthesisService
    private var consecutivePrimaryFailures = 0

    private static let maxPrimaryFailures = 3

    init(primary: any VoiceSynthesisService, fallback: any VoiceSynthesisService) {
        self.primary = primary
        self.fallback = fallback
    }

    private var isPrimaryHealthy: Bool {
        consecutivePrimaryFailures < Self.maxPrimaryFailures
    }

    func speak(_ text: String, style: VoiceStyle) async throws {
        if isPrimaryHealthy {
            do {
                try await primary.speak(text, style: style)
                consecutivePrimaryFailures = 0
                return
            } catch {
                try Task.checkCancellation()
                consecutivePrimaryFailures += 1
            }
        }
        try await fallback.speak(text, style: style)
    }

    func prefetch(_ text: String, style: VoiceStyle) async {
        guard isPrimaryHealthy else { return }
        await primary.prefetch(text, style: style)
    }

    func stop(fade: TimeInterval) async {
        // Both share the engine's voice chain, so one fade covers both.
        await fallback.stop(fade: fade)
        await primary.stop(fade: fade)
    }
}
