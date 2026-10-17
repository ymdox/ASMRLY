import AVFoundation

/// On-device fallback voice: AVSpeechSynthesizer with a slow rate, low pitch and reduced volume.
///
/// Speech is rendered to PCM buffers and played through the engine's voice chain so it gets the
/// same EQ, limiter, ducking and fades as ElevenLabs audio. If rendering yields nothing, the
/// synthesizer plays the line directly instead.
@MainActor
final class AppleVoiceSynthesisService: VoiceSynthesisService {
    private let synthesizer = AVSpeechSynthesizer()
    private let audio: AudioEngineService
    private let voice: AVSpeechSynthesisVoice?
    private var currentCollector: BufferCollector?
    private var isSpeakingDirectly = false

    /// The engine voice chain applies the session volume; this keeps the fallback a touch softer.
    private static let volumeScale: Float = 0.85

    init(audio: AudioEngineService) {
        self.audio = audio
        self.voice = Self.preferredVoice()
    }

    func speak(_ text: String, style: VoiceStyle) async throws {
        try Task.checkCancellation()
        let buffers = await render(makeUtterance(text, style: style, volume: 1))
        try Task.checkCancellation()

        if let merged = AudioBufferTools.merge(buffers) {
            await audio.playVoice(merged, volume: style.volume * Self.volumeScale)
        } else {
            try await speakDirectly(makeUtterance(text, style: style, volume: style.volume * Self.volumeScale))
        }
    }

    func stop(fade: TimeInterval) async {
        currentCollector?.finish()
        if synthesizer.isSpeaking {
            _ = synthesizer.stopSpeaking(at: isSpeakingDirectly ? .word : .immediate)
        }
        await audio.stopVoice(fade: fade)
    }

    // MARK: - Rendering

    private func render(_ utterance: AVSpeechUtterance) async -> [AVAudioPCMBuffer] {
        let collector = BufferCollector()
        currentCollector = collector
        let watchdog = Task.detached {
            await collector.finishWhenIdle()
        }
        synthesizer.write(utterance, toBufferCallback: Self.makeBufferCallback(collector))
        let buffers = await collector.wait()
        watchdog.cancel()
        if currentCollector === collector { currentCollector = nil }
        return buffers
    }

    private func speakDirectly(_ utterance: AVSpeechUtterance) async throws {
        isSpeakingDirectly = true
        audio.setDucked(true)
        defer {
            isSpeakingDirectly = false
            audio.setDucked(false)
        }

        synthesizer.speak(utterance)
        try? await Task.sleep(for: .milliseconds(300))
        while synthesizer.isSpeaking {
            if Task.isCancelled {
                _ = synthesizer.stopSpeaking(at: .word)
                throw CancellationError()
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    private func makeUtterance(_ text: String, style: VoiceStyle, volume: Float) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        let rate = AVSpeechUtteranceDefaultSpeechRate * 0.8 * style.pace
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(rate, AVSpeechUtteranceMaximumSpeechRate))
        utterance.pitchMultiplier = 0.88
        utterance.volume = volume
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        return utterance
    }

    nonisolated private static func makeBufferCallback(_ collector: BufferCollector) -> AVSpeechSynthesizer.BufferCallback {
        { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                // A zero-length buffer marks the end of the utterance.
                collector.finish()
                return
            }
            // Copy, in case the synthesizer reuses its buffer memory.
            collector.append(AudioBufferTools.merge([pcm]) ?? pcm)
        }
    }

    /// Prefers the highest-quality English voice, favouring soft-sounding ones.
    nonisolated private static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let softVoices = ["Ava", "Samantha", "Zoe", "Allison", "Serena", "Susan", "Karen", "Moira"]
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("en")
                && !voice.voiceTraits.contains(.isNoveltyVoice)
                && !voice.voiceTraits.contains(.isPersonalVoice)
        }
        func score(_ voice: AVSpeechSynthesisVoice) -> Int {
            var score = voice.quality.rawValue * 10
            if softVoices.contains(where: { voice.name.hasPrefix($0) }) { score += 5 }
            if voice.language == "en-US" { score += 1 }
            return score
        }
        return candidates.max { score($0) < score($1) } ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

/// Thread-safe collector for buffers delivered by `AVSpeechSynthesizer.write` on a background queue.
private final class BufferCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffers: [AVAudioPCMBuffer] = []
    private var continuation: CheckedContinuation<[AVAudioPCMBuffer], Never>?
    private var isFinished = false
    private var lastActivity = Date()
    private let startedAt = Date()

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.withLock {
            guard !isFinished else { return }
            buffers.append(buffer)
            lastActivity = Date()
        }
    }

    func finish() {
        let waiter: (CheckedContinuation<[AVAudioPCMBuffer], Never>, [AVAudioPCMBuffer])? = lock.withLock {
            guard !isFinished else { return nil }
            isFinished = true
            defer { continuation = nil }
            return continuation.map { ($0, buffers) }
        }
        if let waiter {
            waiter.0.resume(returning: waiter.1)
        }
    }

    func wait() async -> [AVAudioPCMBuffer] {
        await withCheckedContinuation { continuation in
            let finishedBuffers: [AVAudioPCMBuffer]? = lock.withLock {
                if isFinished { return buffers }
                self.continuation = continuation
                return nil
            }
            if let finishedBuffers {
                continuation.resume(returning: finishedBuffers)
            }
        }
    }

    /// Safety net in case the end-of-utterance marker never arrives:
    /// finish once audio stops flowing, or after a hard limit.
    func finishWhenIdle() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(200))
            let shouldFinish: Bool = lock.withLock {
                let now = Date()
                if isFinished { return false }
                if !buffers.isEmpty, now.timeIntervalSince(lastActivity) > 0.8 { return true }
                return now.timeIntervalSince(startedAt) > 8
            }
            if shouldFinish {
                finish()
                return
            }
        }
    }
}
