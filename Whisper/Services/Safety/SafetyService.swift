import Foundation

/// Minimal keyword screen for crisis / self-harm language in what the user says.
/// When it triggers, the session stops the ASMR flow and points to real-world help.
struct SafetyService: Sendable {
    enum Assessment: Equatable, Sendable {
        case ok
        case crisis
    }

    func assess(_ text: String) -> Assessment {
        let normalized = Self.normalize(text)
        return Self.phrases.contains { normalized.contains(" \($0) ") } ? .crisis : .ok
    }

    /// Lowercases, unifies apostrophes and reduces the text to single-space separated words,
    /// padded with spaces so phrases only match on word boundaries.
    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        let separators = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted
        let words = lowered.components(separatedBy: separators).filter { !$0.isEmpty }
        return " " + words.joined(separator: " ") + " "
    }

    private static let phrases = [
        "suicide", "suicidal", "kill myself", "killing myself", "kms",
        "end my life", "ending my life", "take my own life", "take my life", "unalive myself",
        "want to die", "wanna die", "want to be dead", "better off dead", "end it all",
        "no reason to live", "nothing to live for", "don't want to live", "dont want to live",
        "don't want to be alive", "dont want to be alive", "don't want to wake up", "dont want to wake up",
        "hurt myself", "hurting myself", "harm myself", "self harm", "selfharm",
        "cut myself", "cutting myself", "overdose", "can't go on", "cant go on",
    ]
}
