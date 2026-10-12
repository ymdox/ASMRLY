import AVFoundation

enum VoiceServiceError: Error {
    case invalidRequest
    case badResponse(statusCode: Int)
    case decodingFailed
}

/// ElevenLabs text-to-speech, decoded and played through the engine's voice chain.
@MainActor
final class ElevenLabsVoiceService: VoiceSynthesisService {
    private let apiKey: String
    private let voiceID: String
    private let audio: AudioEngineService
    private let session: URLSession

    private static let modelID = "eleven_multilingual_v2"

    init(apiKey: String, voiceID: String, audio: AudioEngineService, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.voiceID = voiceID
        self.audio = audio
        self.session = session
    }

    func speak(_ text: String, style: VoiceStyle) async throws {
        let data = try await synthesize(text, style: style)
        try Task.checkCancellation()
        let buffer = try await Task.detached(priority: .userInitiated) {
            try ElevenLabsVoiceService.decode(data)
        }.value
        try Task.checkCancellation()
        await audio.playVoice(buffer, volume: style.volume)
    }

    func stop(fade: TimeInterval) async {
        await audio.stopVoice(fade: fade)
    }

    private func synthesize(_ text: String, style: VoiceStyle) async throws -> Data {
        guard let encodedVoice = voiceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(encodedVoice)?output_format=mp3_44100_128")
        else { throw VoiceServiceError.invalidRequest }

        let body = SpeechRequest(
            text: text,
            modelId: Self.modelID,
            voiceSettings: .init(
                stability: 0.7,
                similarityBoost: 0.75,
                style: 0,
                useSpeakerBoost: false,
                speed: Double(min(max(0.88 * style.pace, 0.7), 1.2))
            )
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
        let style: Double
        let useSpeakerBoost: Bool
        let speed: Double
    }

    let text: String
    let modelId: String
    let voiceSettings: VoiceSettings
}
