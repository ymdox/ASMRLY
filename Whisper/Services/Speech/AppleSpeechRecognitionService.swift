import AVFoundation
import OSLog
import Speech

/// SFSpeechRecognizer fed by a dedicated input-only AVAudioEngine.
/// The microphone is only active between `startListening` and `stopListening` / `cancelListening`.
@MainActor
final class AppleSpeechRecognitionService: SpeechRecognitionService {
    private let recognizer: SFSpeechRecognizer?
    private let inputEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onPartialResult: (@MainActor (String) -> Void)?
    private var latestTranscript = ""
    private var isTapInstalled = false
    private var didReceiveFinal = false
    private var finalContinuation: CheckedContinuation<Void, Never>?
    /// Ignores late callbacks from a previous recognition.
    private var generation = 0

    private static let finalResultTimeout: TimeInterval = 1.5
    nonisolated private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Whisper", category: "Speech")

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    var isAvailable: Bool {
        guard let recognizer, recognizer.isAvailable else { return false }
        return SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    func startListening(onPartialResult: @escaping @MainActor (String) -> Void) throws {
        cancelListening()
        guard let recognizer, recognizer.isAvailable else {
            Self.logger.error("Speech recognizer unavailable for this language or device.")
            throw SpeechRecognitionError.unavailable
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted else {
            Self.logger.error("Microphone or speech recognition permission not granted.")
            throw SpeechRecognitionError.notAuthorized
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        // Don't force on-device recognition: it fails when the on-device model isn't installed
        // (and always in the simulator). The system still prefers on-device when it can.
        request.requiresOnDeviceRecognition = false

        let input = inputEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            Self.logger.error("No microphone input available (format \(format.description, privacy: .public)).")
            throw SpeechRecognitionError.audioInputFailed
        }

        input.installTap(onBus: 0, bufferSize: 1_024, format: format, block: Self.makeTapBlock(for: request))
        isTapInstalled = true
        inputEngine.prepare()
        do {
            try inputEngine.start()
        } catch {
            Self.logger.error("Could not start microphone: \(error.localizedDescription, privacy: .public)")
            stopAudioInput()
            throw SpeechRecognitionError.audioInputFailed
        }

        generation += 1
        let token = generation
        latestTranscript = ""
        didReceiveFinal = false
        self.onPartialResult = onPartialResult
        self.request = request
        recognitionTask = recognizer.recognitionTask(
            with: request,
            resultHandler: Self.makeResultHandler { [weak self] text, isFinal, failed in
                self?.handleResult(text: text, isFinal: isFinal, failed: failed, token: token)
            }
        )
    }

    func stopListening() async -> String {
        guard let request else { return "" }
        let token = generation
        stopAudioInput()
        request.endAudio()

        if !didReceiveFinal {
            // Give the recognizer a moment to deliver its final transcript.
            let timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.finalResultTimeout))
                self?.resumeWaiter()
            }
            await withCheckedContinuation { continuation in
                finalContinuation = continuation
            }
            timeout.cancel()
        }

        // A new recognition may have started while we waited; leave it alone.
        guard token == generation else { return "" }
        let transcript = latestTranscript
        Self.logger.info("Heard: \"\(transcript, privacy: .private)\" (\(transcript.count, privacy: .public) characters)")
        reset()
        return transcript
    }

    func cancelListening() {
        stopAudioInput()
        recognitionTask?.cancel()
        reset()
    }

    // MARK: - Private

    private func handleResult(text: String?, isFinal: Bool, failed: Bool, token: Int) {
        guard token == generation else { return }
        if let text, !text.isEmpty {
            latestTranscript = text
            onPartialResult?(text)
        }
        if isFinal || failed {
            didReceiveFinal = true
            resumeWaiter()
        }
    }

    private func resumeWaiter() {
        finalContinuation?.resume()
        finalContinuation = nil
    }

    private func stopAudioInput() {
        if inputEngine.isRunning {
            inputEngine.stop()
        }
        if isTapInstalled {
            inputEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
    }

    private func reset() {
        generation += 1
        resumeWaiter()
        recognitionTask = nil
        request = nil
        onPartialResult = nil
        latestTranscript = ""
    }

    nonisolated private static func makeTapBlock(for request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
        }
    }

    /// Recognition callbacks arrive on a background queue; hop to the main actor with plain values.
    nonisolated private static func makeResultHandler(
        _ forward: @escaping @MainActor @Sendable (String?, Bool, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            if let error {
                Self.logger.error("Recognition ended with error: \(error.localizedDescription, privacy: .public)")
            }
            Task { @MainActor in
                forward(text, isFinal, failed)
            }
        }
    }
}
