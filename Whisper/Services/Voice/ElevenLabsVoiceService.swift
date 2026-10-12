import AVFoundation

enum VoiceServiceError: Error {
    case invalidRequest
    case badResponse(statusCode: Int)
    case decodingFailed
}

/// ElevenLabs text-to-speech, decoded and played through the engine's voice chain
/// (EQ, limiter, ducking and fades apply exactly as for any other voice).
///
/// Synthesized lines are cached in memory, and fixed lines (opening / goodnight) can be
/// prefetched so they play without a network wait.
@MainActor
final class ElevenLabsVoiceService: VoiceSynthesisService {
    static let defaultModelID = "eleven_multilingual_v2"

    private let apiKey: String
    private let voiceID: String
    private let modelID: String
    private let audio: AudioEngineService
    private let session: URLSession

    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var cacheOrder: [String] = []
    private var inFlight: [String: Task<UncheckedSendable<AVAudioPCMBuffer>, Error>] = [:]
    private static let cacheLimit = 24

    /// Eleven v3 understands audio tags such as `[whispers]` but takes fewer voice settings.
    private var isV3: Bool { modelID.hasPrefix("eleven_v3") }

    init(apiKey: String, voiceID: String, modelID: String?, audio: AudioEngineService, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.voiceID = voiceID
        self.modelID = modelID ?? Self.defaultModelID
        self.audio = audio
        self.session = session
    }

    func speak(_ text: String, style: VoiceStyle) async throws {
        let buffer = try await buffer(for: text, style: style)
        try Task.checkCancellation()
        await audio.playVoice(buffer, volume: style.volume)
    }

    func prefetch(_ text: String, style: VoiceStyle) async {
        _ = try? await buffer(for: text, style: style)
    }

    func stop(fade: TimeInterval) async {
        await audio.stopVoice(fade: fade)
    }

    // MARK: - Synthesis & cache

    private func buffer(for text: String, style: VoiceStyle) async throws -> AVAudioPCMBuffer {
        let key = Self.cacheKey(text: text, style: style)
        if let cached = cache[key] { return cached }

        let task: Task<UncheckedSendable<AVAudioPCMBuffer>, Error>
        if let existing = inFlight[key] {
            task = existing
        } else {
            // Unstructured on purpose: if the caller is cancelled, the result still lands in the cache.
            task = Task { [weak self] in
                guard let self else { throw CancellationError() }
                let data = try await self.synthesize(text, style: style)
                return try await Task.detached(priority: .userInitiated) {
                    UncheckedSendable(value: try ElevenLabsVoiceService.decode(data))
                }.value
            }
            inFlight[key] = task
        }

        do {
            let result = try await task.value
            inFlight[key] = nil
            store(result.value, for: key)
            return result.value
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    private func store(_ buffer: AVAudioPCMBuffer, for key: String) {
        guard cache[key] == nil else { return }
        cache[key] = buffer
        cacheOrder.append(key)
        if cacheOrder.count > Self.cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
    }

    /// Volume is applied at playback, so only text and pace affect the audio.
    private static func cacheKey(text: String, style: VoiceStyle) -> String {
        "\((style.pace * 20).rounded())|\(text)"
    }

    private func synthesize(_ text: String, style: VoiceStyle) async throws -> Data {
        guard let encodedVoice = voiceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(encodedVoice)?output_format=mp3_44100_128")
        else { throw VoiceServiceError.invalidRequest }

        let settings: SpeechRequest.VoiceSettings
        if isV3 {
            settings = .init(stability: 0.5, similarityBoost: 0.75, style: nil, useSpeakerBoost: nil, speed: nil)
        } else {
            settings = .init(
                stability: 0.7,
                similarityBoost: 0.75,
                style: 0,
                useSpeakerBoost: false,
                speed: Double(min(max(0.88 * style.pace, 0.7), 1.2))
            )
        }
        let body = SpeechRequest(
            text: isV3 ? "[whispers] \(text)" : text,
            modelId: modelID,
            voiceSettings: settings
        )

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw VoiceServiceError.badResponse(statusCode: -1) }
        guard (200..<300).contains(http.statusCode), !data.isEmpty else {
            throw VoiceServiceError.badResponse(statusCode: http.statusCode)
        }
        return data
    }

    nonisolated private static func decode(_ data: Data) throws -> AVAudioPCMBuffer {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-voice-\(UUID().uuidString)")
            .appendingPathExtension("mp3")
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try AVAudioFile(forReading: url)
        guard file.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { throw VoiceServiceError.decodingFailed }
        try file.read(into: buffer)
        return buffer
    }
}

private struct SpeechRequest: Encodable {
    struct VoiceSettings: Encodable {
        let stability: Double
        let similarityBoost: Double
        let style: Double?
        let useSpeakerBoost: Bool?
        let speed: Double?
    }

    let text: String
    let modelId: String
    let voiceSettings: VoiceSettings
}
