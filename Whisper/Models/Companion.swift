import Foundation

struct Companion: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let tagline: String
    /// First words spoken when a session starts.
    let openingLine: String
    /// Spoken softly as the session moves into ambience only.
    let closingLine: String

    static let luna = Companion(
        id: "luna",
        name: "Luna",
        tagline: "warm and comforting",
        openingLine: "Hi… I'm Luna. I'm right here with you. How are you feeling tonight?",
        closingLine: "I'll let the sounds carry you now… rest easy… goodnight."
    )
}
