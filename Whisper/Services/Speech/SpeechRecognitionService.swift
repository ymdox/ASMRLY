import Foundation

enum SpeechRecognitionError: Error {
    case unavailable
    case notAuthorized
    case audioInputFailed
}

@MainActor
protocol SpeechRecognitionService: AnyObject {
    /// False when recognition isn't supported, authorized or currently available.
    var isAvailable: Bool { get }
    /// Starts capturing the microphone. Partial transcripts are delivered as the user speaks.
    func startListening(onPartialResult: @escaping @MainActor (String) -> Void) throws
    /// Stops capturing and returns the best final transcript (empty if nothing was heard).
    func stopListening() async -> String
    /// Stops capturing and discards the transcript.
    func cancelListening()
}

/// Used when speech recognition can't be offered; the session runs in Just Listen mode.
@MainActor
final class UnavailableSpeechRecognitionService: SpeechRecognitionService {
    var isAvailable: Bool { false }

    func startListening(onPartialResult: @escaping @MainActor (String) -> Void) throws {
        throw SpeechRecognitionError.unavailable
    }

    func stopListening() async -> String { "" }

    func cancelListening() {}
}
