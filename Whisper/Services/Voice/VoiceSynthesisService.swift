import Foundation

/// How a line should be voiced. Volume and pace decrease as the session winds down.
struct VoiceStyle: Equatable, Sendable {
    /// 0…1 playback volume.
    var volume: Float
    /// 1 = normal whisper pace; lower is slower.
    var pace: Float

    static let conversation = VoiceStyle(volume: 0.95, pace: 1)
}

@MainActor
protocol VoiceSynthesisService: AnyObject {
    /// Speaks `text` and returns when playback has finished (or was stopped).
    func speak(_ text: String, style: VoiceStyle) async throws
    /// Fades out and stops any current speech.
    func stop(fade: TimeInterval) async
    /// Optionally prepares a line ahead of time (e.g. downloads it) so it can play instantly.
    func prefetch(_ text: String, style: VoiceStyle) async
}

extension VoiceSynthesisService {
    func prefetch(_ text: String, style: VoiceStyle) async {}
}

/// Voice stand-in that only waits as long as the line would take to say. Used for previews.
@MainActor
final class SilentVoiceService: VoiceSynthesisService {
    func speak(_ text: String, style: VoiceStyle) async throws {
        let words = Double(text.split(separator: " ").count)
        try await Task.sleep(for: .seconds(max(1.5, words * 0.45 / Double(max(style.pace, 0.5)))))
    }

    func stop(fade: TimeInterval) async {}
}
