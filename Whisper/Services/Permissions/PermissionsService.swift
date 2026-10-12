import AVFoundation
import Speech

/// Microphone + speech recognition permissions. The app works without them (Just Listen mode).
@MainActor
final class PermissionsService {
    /// True while either permission has never been asked — show our primer first.
    var needsPrompt: Bool {
        AVAudioApplication.shared.recordPermission == .undetermined
            || SFSpeechRecognizer.authorizationStatus() == .notDetermined
    }

    /// Shows the system prompts as needed. Returns true when talking is possible.
    @discardableResult
    func requestAccess() async -> Bool {
        let microphoneGranted: Bool
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            microphoneGranted = true
        case .undetermined:
            microphoneGranted = await AVAudioApplication.requestRecordPermission()
        default:
            microphoneGranted = false
        }
        guard microphoneGranted else { return false }

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await Self.requestSpeechAuthorization() == .authorized
        default:
            return false
        }
    }

    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
