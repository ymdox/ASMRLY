import Foundation

struct Companion: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let tagline: String
    /// First words spoken when a session starts.
    let openingLine: String
    /// Opening used in Just Listen mode, where no answer is expected.
    let listeningOpeningLine: String
    /// Spoken softly as the session moves into ambience only.
    let closingLine: String

    static let luna = Companion(
        id: "luna",
        name: "Luna",
        tagline: "warm and comforting",
        openingLine: "Hi… I'm Luna. I'm right here with you. How are you feeling tonight?",
        listeningOpeningLine: "Hi… I'm Luna. Just get comfortable… I'll keep you company tonight.",
        closingLine: "I'll let the sounds carry you now… rest easy… goodnight."
    )
}
