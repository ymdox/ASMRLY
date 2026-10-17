import Foundation

enum Ambience: String, CaseIterable, Identifiable, Sendable {
    case rain
    case fireplace
    case ocean
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rain: "Rain"
        case .fireplace: "Fireplace"
        case .ocean: "Ocean"
        case .none: "None"
        }
    }

    var symbolName: String {
        switch self {
        case .rain: "cloud.rain"
        case .fireplace: "flame"
        case .ocean: "water.waves"
        case .none: "speaker.slash"
        }
    }

    /// Base file name of the bundled loop in Resources/Sounds (any of .m4a, .caf, .wav, .mp3).
    var soundFileName: String? {
        self == .none ? nil : rawValue
    }
}
