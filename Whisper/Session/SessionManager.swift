import Foundation
import Observation

/// Drives one ASMR session: the timeline, the companion's turns, listening and audio.
/// All UI state lives here; views only read it and call the intent methods below.
@MainActor
@Observable
final class SessionManager: Identifiable {
    static let voiceUnavailableMessage = "Voice isn't available right now. Your soundscape can keep playing."
    static let listeningUnavailableMessage = "Listening isn't available right now. Your soundscape can keep playing."
    private static let maxHistory = 10

    let id = UUID()
    let companion: Companion
    let ambience: Ambience
    let configuration: SessionConfiguration
    /// Microphone and speech recognition are both permitted and available.
    let canTalk: Bool

    private(set) var phase: SessionPhase = .preparing
    private(set) var activity: CompanionActivity = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var transcript: [TranscriptLine] = []
    private(set) var liveUserText: String?
    private(set) var notice: String?
    private(set) var mode: InteractionMode
    private(set) var ambienceVolume: Float = 0.5
    private(set) var isEnding = false
    /// Crisis language was detected: the immersive flow stops and support info is shown.
    private(set) var safetyTriggered = false

    @ObservationIgnored private let audio: AudioEngineService
    @ObservationIgnored private let ai: any AIConversationService
    @ObservationIgnored private let speech: any SpeechRecognitionService
    @ObservationIgnored private let voice: any VoiceSynthesisService
    @ObservationIgnored private let safety: SafetyService

    @ObservationIgnored private var history: [ChatMessage] = []
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    @ObservationIgnored private var turnTask: Task<Void, Never>?
    @ObservationIgnored private var monologueTask: Task<Void, Never>?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    @ObservationIgnored private var transcriptTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var lastTick: Date?
    @ObservationIgnored private var phaseBeforePause: SessionPhase = .conversation
    @ObservationIgnored private var pausedByInterruption = false
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var finalFadeStarted = false
    @ObservationIgnored private var consecutiveFailures = 0

    init(
        companion: Companion,
        ambience: Ambience,
        configuration: SessionConfiguration,
        mode: InteractionMode,
        canTalk: Bool,
        dependencies: AppDependencies
    ) {
        self.companion = companion
        self.ambience = ambience
        self.configuration = configuration
        self.mode = canTalk ? mode : .justListen
        self.canTalk = canTalk
        self.audio = dependencies.audio
        self.ai = dependencies.ai
        self.speech = dependencies.speech
        self.voice = dependencies.voice
        self.safety = dependencies.safety
    }

    // MARK: - Derived state

    var statusText: String {
        switch activity {
        case .listening: return "Listening"
        case .thinking: return "Thinking"
        case .whispering: return "Whispering"
        case .idle: break
        }
        switch phase {
        case .preparing: return "Settling in"
        case .conversation, .relaxation: return "Relaxing"
        case .ambientOnly, .error: return "Ambient"
        case .paused: return "Paused"
        case .completed: return "Sleep well"
        }
    }

    var isPaused: Bool { phase == .paused }

    var isMicrophoneEnabled: Bool {
        canTalk && mode == .talk && phase.allowsVoice && !isEnding
    }

    var canPause: Bool {
        (phase.isRunning || phase == .paused) && !isEnding
    }

    /// The timeline phase, ignoring a temporary pause.
    private var timelinePhase: SessionPhase {
        phase == .paused ? phaseBeforePause : phase
    }

    /// 0…1 progress through the current timeline phase.
    private var stageProgress: Double {
        let progress: Double
        switch timelinePhase {
        case .conversation:
            progress = elapsed / max(configuration.conversationDuration, 1)
        case .relaxation:
            progress = (elapsed - configuration.conversationDuration) / max(configuration.relaxationDuration, 1)
        default:
            progress = 1
        }
        return min(max(progress, 0), 1)
    }

    /// Voice gets quieter and slower through the relaxation phase.
    private var voiceStyle: VoiceStyle {
        guard timelinePhase == .relaxation else { return .conversation }
        let progress = Float(stageProgress)
        return VoiceStyle(volume: 0.9 - 0.45 * progress, pace: 1 - 0.12 * progress)
    }

    /// Silence between the companion's unprompted whispers; grows during relaxation.
    private var monologuePause: TimeInterval {
        let base: TimeInterval = timelinePhase == .relaxation ? 12 + 18 * stageProgress : 7
        // Back off gently if the voice keeps failing (e.g. offline).
        return base + Double(min(consecutiveFailures, 4)) * 15
    }

    // MARK: - Lifecycle

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        audio.onEvent = { [weak self] event in
            self?.handleAudioEvent(event)
        }
        audio.setAmbienceLevel(ambienceVolume)

        do {
            try await audio.prepare(ambience: ambience)
        } catch {
            phase = .error
            notice = "Your soundscape couldn't start right now. Please try again in a moment."
            return
        }
        guard !isEnding else {
            // Torn down while the engine was still starting: release it again.
            await audio.fadeOutAndStop(duration: SessionConfiguration.voiceFade)
            return
        }

        audio.startAmbience(fadeIn: SessionConfiguration.ambienceFadeIn)
        try? await Task.sleep(for: .seconds(1.5))
        guard phase == .preparing, !isEnding else { return }

        phase = .conversation
        startClock()

        let opening = mode == .talk ? companion.openingLine : companion.listeningOpeningLine
        turnTask = Task { [weak self] in
            await self?.speak(opening, style: .conversation)
        }
        updateMonologue()
    }

    /// User tapped End: fade everything out, then complete.
    func end() async {
        guard !isEnding else { return }
        isEnding = true
        stopAllTasks()
        let voice = self.voice
        Task { await voice.stop(fade: SessionConfiguration.voiceFade) }
        await audio.fadeOutAndStop(duration: SessionConfiguration.endFade)
        phase = .completed
    }

    /// The session view went away: cancel everything and release audio with a short fade.
    func teardown() {
        let alreadyStopped = isEnding || phase == .completed
        isEnding = true
        stopAllTasks()
        guard !alreadyStopped else { return }
        let voice = self.voice
        let audio = self.audio
        Task {
            await voice.stop(fade: SessionConfiguration.voiceFade)
        }
        Task {
            await audio.fadeOutAndStop(duration: SessionConfiguration.voiceFade)
        }
    }

    // MARK: - Intents

    func setMode(_ newMode: InteractionMode) {
        guard newMode != mode, newMode == .justListen || canTalk else { return }
        mode = newMode
        if newMode == .justListen { cancelListening() }
        updateMonologue()
    }

    func setAmbienceVolume(_ volume: Float) {
        ambienceVolume = min(max(volume, 0), 1)
        audio.setAmbienceLevel(ambienceVolume)
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    func pause() {
        guard phase.isRunning, !isEnding else { return }
        phaseBeforePause = phase
        phase = .paused
        finalFadeStarted = false
        monologueTask?.cancel()
        monologueTask = nil
        turnTask?.cancel()
        turnTask = nil
        cancelListening()
        activity = .idle

        let voice = self.voice
        let audio = self.audio
        Task { await voice.stop(fade: SessionConfiguration.voiceFade) }
        Task { await audio.pause(fade: SessionConfiguration.pauseFade) }
    }

    func resume() {
        guard phase == .paused, !isEnding else { return }
        pausedByInterruption = false
        phase = phaseBeforePause
        lastTick = .now
        audio.resume(fade: SessionConfiguration.pauseFade)
        updateMonologue()
    }

    func beginListening() {
        guard isMicrophoneEnabled, activity != .listening else { return }

        // The user wants to talk: gently fade the companion out.
        turnTask?.cancel()
        turnTask = nil
        let voice = self.voice
        Task { await voice.stop(fade: SessionConfiguration.voiceFade) }

        do {
            try speech.startListening { [weak self] partial in
                guard let self, self.activity == .listening else { return }
                self.liveUserText = partial
            }
            liveUserText = ""
            activity = .listening
        } catch {
            activity = .idle
            showNotice(Self.listeningUnavailableMessage)
        }
    }

    func finishListening() {
        guard activity == .listening else { return }
        activity = .thinking
        turnTask = Task { [weak self] in
            guard let self else { return }
            let text = await self.speech.stopListening().trimmingCharacters(in: .whitespacesAndNewlines)
            self.liveUserText = nil
            guard !Task.isCancelled else { return }
            guard !text.isEmpty else {
                self.activity = .idle
                return
            }
            guard self.safety.assess(text) == .ok else {
                self.triggerSafetyStop()
                return
            }
            self.appendTranscript(.user, text)
            await self.runTurn(userText: text)
        }
    }

    // MARK: - Safety

    /// Stops the roleplay entirely (no further whispers) and fades the soundscape out.
    private func triggerSafetyStop() {
        safetyTriggered = true
        isEnding = true
        stopAllTasks()
        transcript.removeAll()
        liveUserText = nil
        noticeTask?.cancel()
        notice = nil

        let voice = self.voice
        let audio = self.audio
        Task { await voice.stop(fade: SessionConfiguration.voiceFade) }
        Task { await audio.fadeOutAndStop(duration: SessionConfiguration.endFade) }
    }

    // MARK: - Timeline

    private func startClock() {
        lastTick = .now
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        let now = Date.now
        let delta = now.timeIntervalSince(lastTick ?? now)
        lastTick = now
        guard phase.isRunning, !isEnding else { return }

        elapsed += delta
        let target = configuration.phase(at: elapsed)
        if target != phase {
            transition(to: target)
        }

        let remaining = configuration.totalDuration - elapsed
        if phase == .ambientOnly, !finalFadeStarted, remaining <= configuration.finalFadeDuration {
            finalFadeStarted = true
            audio.fadeAmbience(to: 0, duration: max(remaining, SessionConfiguration.endFade))
        }
    }

    private func transition(to newPhase: SessionPhase) {
        phase = newPhase
        switch newPhase {
        case .relaxation:
            updateMonologue()
        case .ambientOnly:
            monologueTask?.cancel()
            monologueTask = nil
            cancelListening()
            turnTask?.cancel()
            let closing = companion.closingLine
            let voice = self.voice
            turnTask = Task { [weak self] in
                await voice.stop(fade: SessionConfiguration.voiceFade)
                guard !Task.isCancelled else { return }
                await self?.speak(closing, style: VoiceStyle(volume: 0.45, pace: 0.85))
            }
        case .completed:
            Task { await self.complete() }
        default:
            break
        }
    }

    private func complete() async {
        stopAllTasks()
        await voice.stop(fade: SessionConfiguration.voiceFade)
        await audio.fadeOutAndStop(duration: SessionConfiguration.endFade)
    }

    private func stopAllTasks() {
        clockTask?.cancel()
        clockTask = nil
        monologueTask?.cancel()
        monologueTask = nil
        turnTask?.cancel()
        turnTask = nil
        transcriptTasks.values.forEach { $0.cancel() }
        transcriptTasks.removeAll()
        cancelListening()
        activity = .idle
    }

    // MARK: - Companion turns

    private func updateMonologue() {
        let shouldRun = !isEnding
            && ((phase == .conversation && mode == .justListen) || phase == .relaxation)
        if shouldRun {
            guard monologueTask == nil else { return }
            monologueTask = Task { [weak self] in
                await self?.runMonologue()
            }
        } else {
            monologueTask?.cancel()
            monologueTask = nil
        }
    }

    private func runMonologue() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(monologuePause))
            guard !Task.isCancelled else { return }
            guard activity == .idle, phase.allowsVoice else { continue }
            let turn = Task { [weak self] in
                await self?.runTurn(userText: nil)
            }
            turnTask = turn
            await turn.value
        }
    }

    private func runTurn(userText: String?) async {
        activity = .thinking
        let context = ConversationContext(
            companionName: companion.name,
            stage: timelinePhase == .relaxation ? .relaxation : .conversation,
            stageProgress: stageProgress,
            isMonologue: userText == nil
        )

        do {
            let reply = try await ai.reply(to: userText, history: history, context: context)
            guard !Task.isCancelled else { return }
            consecutiveFailures = 0
            guard phase.allowsVoice else {
                activity = .idle
                return
            }
            if let userText {
                history.append(ChatMessage(role: .user, content: userText))
            }
            history.append(ChatMessage(role: .assistant, content: reply))
            if history.count > Self.maxHistory {
                history.removeFirst(history.count - Self.maxHistory)
            }
            await speak(reply, style: voiceStyle)
        } catch {
            guard !Task.isCancelled else { return }
            consecutiveFailures += 1
            activity = .idle
            showNotice(Self.voiceUnavailableMessage)
        }
    }

    private func speak(_ text: String, style: VoiceStyle) async {
        activity = .whispering
        appendTranscript(.companion, text)
        do {
            try await voice.speak(text, style: style)
        } catch {
            if !Task.isCancelled {
                showNotice(Self.voiceUnavailableMessage)
            }
        }
        guard !Task.isCancelled else { return }
        activity = .idle
    }

    private func cancelListening() {
        guard activity == .listening else { return }
        speech.cancelListening()
        liveUserText = nil
        activity = .idle
    }

    // MARK: - Audio events

    private func handleAudioEvent(_ event: AudioEvent) {
        switch event {
        case .interruptionBegan:
            guard phase.isRunning else { return }
            pause()
            pausedByInterruption = true
        case .interruptionEnded(let shouldResume):
            if pausedByInterruption, phase == .paused {
                pausedByInterruption = false
                if shouldResume { resume() }
            } else if phase.isRunning || phase == .preparing {
                // Interrupted outside a pausable moment: just fade the soundscape back in.
                audio.resume(fade: SessionConfiguration.pauseFade)
            }
        }
    }

    // MARK: - Transcript & notices

    private func appendTranscript(_ speaker: TranscriptLine.Speaker, _ text: String) {
        let line = TranscriptLine(speaker: speaker, text: text)
        transcript.append(line)
        while transcript.count > 2 {
            let removed = transcript.removeFirst()
            transcriptTasks.removeValue(forKey: removed.id)?.cancel()
        }

        let id = line.id
        transcriptTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(SessionConfiguration.transcriptLinger))
            guard !Task.isCancelled, let self else { return }
            self.transcript.removeAll { $0.id == id }
            self.transcriptTasks[id] = nil
        }
    }

    private func showNotice(_ message: String) {
        notice = message
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }
}
