import AVFoundation
import AudioToolbox

/// Events the audio layer reports up to the session.
enum AudioEvent: Sendable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
}

enum AudioEngineError: Error {
    case engineFailedToStart
}

/// Owns the single AVAudioEngine used for a session.
///
/// Graph:
/// ```
/// ambiencePlayer ─▶ ambienceMixer ───────────────────────────▶ mainMixer ─▶ output
/// voicePlayer ─▶ voiceEQ (warmth) ─▶ voiceLimiter (no clipping) ─┘
/// ```
/// Every level change is ramped; nothing is ever cut abruptly.
@MainActor
final class AudioEngineService {
    var onEvent: (@MainActor (AudioEvent) -> Void)?

    /// User-facing ambience level (0…1), set from the session slider.
    private(set) var ambienceLevel: Float = 0.5

    private let engine = AVAudioEngine()
    private let ambiencePlayer = AVAudioPlayerNode()
    private let ambienceMixer = AVAudioMixerNode()
    private let voicePlayer = AVAudioPlayerNode()
    private let voiceEQ = AVAudioUnitEQ(numberOfBands: 2)
    private let voiceLimiter = AudioEngineService.makeLimiter()
    private lazy var voiceFormat: AVAudioFormat =
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) ?? engine.mainMixerNode.outputFormat(forBus: 0)

    private var ambienceBuffer: AVAudioPCMBuffer?
    private var isGraphAttached = false
    private var isActive = false
    private var isPausedByUser = false
    private var isVoiceActive = false
    private var needsAmbienceRestart = false
    /// Incremented on every prepare so a late shutdown from an old session can't stop a new one.
    private var generation = 0

    // Independent gain stages, each ramped separately.
    private var duckLevel: Float = 1
    private var fadeLevel: Float = 0
    private var masterLevel: Float = 1
    private var ramps: [RampTarget: Task<Void, Never>] = [:]
    private var observers: [NSObjectProtocol] = []

    private enum RampTarget: Hashable {
        case ambienceFade, duck, master, voice
    }

    private static let rampStepsPerSecond = 60.0
    private static let duckedLevel: Float = 0.55

    init() {
        observeNotifications()
    }

    // MARK: - Lifecycle

    /// Configures the audio session, loads the ambience loop and starts the engine (silent).
    func prepare(ambience: Ambience) async throws {
        generation += 1
        cancelAllRamps()
        try configureSession()

        let buffer = await AmbienceLoader.loadBuffer(for: ambience)
        ambienceBuffer = buffer
        buildGraph(ambienceFormat: buffer?.format)

        isPausedByUser = false
        needsAmbienceRestart = false
        apply(0, to: .ambienceFade)
        apply(1, to: .duck)
        apply(1, to: .master)
        applyAmbienceVolume()

        guard ensureEngineRunning() else { throw AudioEngineError.engineFailedToStart }
        isActive = true
    }

    /// Fades the whole mix out, then stops the engine and releases the audio session.
    func fadeOutAndStop(duration: TimeInterval) async {
        let token = generation
        if engine.isRunning, masterLevel > 0 {
            await ramp(.master, to: 0, duration: duration).value
        }
        guard token == generation else { return }
        shutdown()
    }

    private func shutdown() {
        cancelAllRamps()
        isActive = false
        isVoiceActive = false
        ambiencePlayer.stop()
        voicePlayer.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Ambience

    func startAmbience(fadeIn duration: TimeInterval) {
        guard let buffer = ambienceBuffer, ensureEngineRunning() else { return }
        restartAmbienceLoop(with: buffer)
        apply(0, to: .ambienceFade)
        ramp(.ambienceFade, to: 1, duration: duration)
    }

    func setAmbienceLevel(_ level: Float) {
        ambienceLevel = min(max(level, 0), 1)
        applyAmbienceVolume()
    }

    func fadeAmbience(to level: Float, duration: TimeInterval) {
        ramp(.ambienceFade, to: level, duration: duration)
    }

    private func restartAmbienceLoop(with buffer: AVAudioPCMBuffer) {
        ambiencePlayer.stop()
        ambiencePlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        ambiencePlayer.play()
        needsAmbienceRestart = false
    }

    private func applyAmbienceVolume() {
        ambiencePlayer.volume = ambienceLevel * duckLevel
    }

    // MARK: - Voice

    /// Plays a voice buffer through the voice chain, ducking the ambience while it speaks.
    /// Returns when playback finishes or the voice is stopped.
    func playVoice(_ buffer: AVAudioPCMBuffer, volume: Float) async {
        guard ensureEngineRunning(),
              let converted = AudioBufferTools.convert(buffer, to: voiceFormat),
              converted.frameLength > 0 else { return }

        ramps[.voice]?.cancel()
        voicePlayer.volume = volume
        isVoiceActive = true
        setDucked(true)
        if !voicePlayer.isPlaying { voicePlayer.play() }

        await Self.schedule(converted, on: voicePlayer)

        isVoiceActive = false
        setDucked(false)
    }

    /// Fades the voice out, then stops it.
    func stopVoice(fade duration: TimeInterval) async {
        guard isVoiceActive else { return }
        await ramp(.voice, to: 0, duration: duration).value
        voicePlayer.stop()
        isVoiceActive = false
        setDucked(false)
    }

    /// Ducks the ambience under a voice that is not played through this engine
    /// (e.g. the AVSpeechSynthesizer direct-playback fallback).
    func setDucked(_ ducked: Bool) {
        ramp(.duck, to: ducked ? Self.duckedLevel : 1, duration: ducked ? 0.8 : 2.0)
    }

    nonisolated private static func schedule(_ buffer: AVAudioPCMBuffer, on player: AVAudioPlayerNode) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Called once, either when the buffer finished playing or when the player was stopped.
            player.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { _ in
                continuation.resume()
            }
        }
    }

    // MARK: - Pause / resume

    func pause(fade duration: TimeInterval) async {
        isPausedByUser = true
        await ramp(.master, to: 0, duration: duration).value
        guard isPausedByUser, isActive else { return }
        voicePlayer.stop()
        isVoiceActive = false
        engine.pause()
    }

    func resume(fade duration: TimeInterval) {
        isPausedByUser = false
        guard isActive, ensureEngineRunning() else { return }
        if needsAmbienceRestart, let buffer = ambienceBuffer {
            restartAmbienceLoop(with: buffer)
        }
        ramp(.master, to: 1, duration: duration)
    }

    // MARK: - Engine setup

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // playAndRecord so the microphone works mid-session; defaultToSpeaker so
        // playback isn't routed to the earpiece. Background audio is enabled in Info.plist.
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setActive(true)
    }

    private func buildGraph(ambienceFormat: AVAudioFormat?) {
        if engine.isRunning { engine.stop() }

        if !isGraphAttached {
            engine.attach(ambiencePlayer)
            engine.attach(ambienceMixer)
            engine.attach(voicePlayer)
            engine.attach(voiceEQ)
            engine.attach(voiceLimiter)
            configureVoiceEffects()
            isGraphAttached = true
        }

        let mainMixer = engine.mainMixerNode
        let ambienceFormat = ambienceFormat ?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        engine.connect(ambiencePlayer, to: ambienceMixer, fromBus: 0, toBus: 0, format: ambienceFormat)
        engine.connect(ambienceMixer, to: mainMixer, fromBus: 0, toBus: 0, format: nil)
        engine.connect(voicePlayer, to: voiceEQ, format: voiceFormat)
        engine.connect(voiceEQ, to: voiceLimiter, format: voiceFormat)
        engine.connect(voiceLimiter, to: mainMixer, fromBus: 0, toBus: 1, format: voiceFormat)
    }

    private func configureVoiceEffects() {
        // Gentle high-pass to remove rumble, and a soft high-shelf cut for a warmer, less sibilant whisper.
        let highPass = voiceEQ.bands[0]
        highPass.filterType = .highPass
        highPass.frequency = 90
        highPass.bypass = false

        let shelf = voiceEQ.bands[1]
        shelf.filterType = .highShelf
        shelf.frequency = 7_000
        shelf.gain = -4
        shelf.bypass = false

        // Peak limiter keeps the voice from clipping when it sits above the ambience.
        let unit = voiceLimiter.audioUnit
        AudioUnitSetParameter(unit, kLimiterParam_AttackTime, kAudioUnitScope_Global, 0, 0.012, 0)
        AudioUnitSetParameter(unit, kLimiterParam_DecayTime, kAudioUnitScope_Global, 0, 0.06, 0)
        AudioUnitSetParameter(unit, kLimiterParam_PreGain, kAudioUnitScope_Global, 0, -2, 0)
    }

    nonisolated private static func makeLimiter() -> AVAudioUnitEffect {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: description)
    }

    @discardableResult
    private func ensureEngineRunning() -> Bool {
        if engine.isRunning { return true }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Ramps

    @discardableResult
    private func ramp(_ target: RampTarget, to end: Float, duration: TimeInterval) -> Task<Void, Never> {
        ramps[target]?.cancel()
        let start = value(of: target)
        guard duration > 0, abs(end - start) > 0.0001 else {
            apply(end, to: target)
            ramps[target] = nil
            return Task {}
        }

        let steps = max(1, Int(duration * Self.rampStepsPerSecond))
        let stepDuration = duration / Double(steps)
        let task = Task { [weak self] in
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(stepDuration))
                guard !Task.isCancelled, let self else { return }
                let progress = Float(step) / Float(steps)
                let eased = progress * progress * (3 - 2 * progress) // smoothstep
                self.apply(start + (end - start) * eased, to: target)
            }
        }
        ramps[target] = task
        return task
    }

    private func cancelAllRamps() {
        ramps.values.forEach { $0.cancel() }
        ramps.removeAll()
    }

    private func value(of target: RampTarget) -> Float {
        switch target {
        case .ambienceFade: fadeLevel
        case .duck: duckLevel
        case .master: masterLevel
        case .voice: voicePlayer.volume
        }
    }

    private func apply(_ value: Float, to target: RampTarget) {
        switch target {
        case .ambienceFade:
            fadeLevel = value
            ambienceMixer.outputVolume = value
        case .duck:
            duckLevel = value
            applyAmbienceVolume()
        case .master:
            masterLevel = value
            engine.mainMixerNode.outputVolume = value
        case .voice:
            voicePlayer.volume = value
        }
    }

    // MARK: - Interruptions & route changes

    private func observeNotifications() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let event = Self.interruptionEvent(from: notification) else { return }
            MainActor.assumeIsolated {
                self?.handle(event)
            }
        })
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleConfigurationChange()
            }
        })
    }

    nonisolated private static func interruptionEvent(from notification: Notification) -> AudioEvent? {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return nil }
        switch type {
        case .began:
            return .interruptionBegan
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            return .interruptionEnded(shouldResume: options.contains(.shouldResume))
        @unknown default:
            return nil
        }
    }

    private func handle(_ event: AudioEvent) {
        guard isActive else { return }
        if case .interruptionBegan = event {
            // The system already silenced us; make sure we fade back in later rather than jump.
            needsAmbienceRestart = true
            isVoiceActive = false
            cancelAllRamps()
            apply(0, to: .master)
        }
        onEvent?(event)
    }

    /// Route changes (e.g. headphones unplugged) stop the engine; restart it quietly.
    private func handleConfigurationChange() {
        guard isActive, !isPausedByUser, !engine.isRunning else { return }
        needsAmbienceRestart = true
        guard ensureEngineRunning(), let buffer = ambienceBuffer else { return }
        restartAmbienceLoop(with: buffer)
    }
}
