import AVFoundation

/// Loads the ambience loop for a soundscape.
///
/// Looks for `Resources/Sounds/<name>.<ext>` in the app bundle first (rain, fireplace, ocean;
/// m4a / caf / wav / mp3 / aiff). If no file is bundled, a soft procedural loop is generated
/// so the app always has something to play.
enum AmbienceLoader {
    static let supportedExtensions = ["m4a", "caf", "wav", "mp3", "aiff"]

    static func loadBuffer(for ambience: Ambience) async -> AVAudioPCMBuffer? {
        guard let name = ambience.soundFileName else { return nil }
        let loaded = await Task.detached(priority: .userInitiated) { () -> UncheckedSendable<AVAudioPCMBuffer?> in
            if let url = AmbienceLoader.bundledURL(named: name), let buffer = AmbienceLoader.readBuffer(from: url) {
                return UncheckedSendable(value: buffer)
            }
            return UncheckedSendable(value: ProceduralAmbience.makeBuffer(for: ambience))
        }.value
        return loaded.value
    }

    static func bundledURL(named name: String) -> URL? {
        for fileExtension in supportedExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: name, withExtension: fileExtension) {
                return url
            }
        }
        return nil
    }

    private static func readBuffer(from url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            let frameCount = AVAudioFrameCount(file.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            return nil
        }
    }
}
