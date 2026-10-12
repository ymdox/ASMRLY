import Foundation

/// Prompt and output shaping for LLM-backed companions.
enum CompanionPrompt {
    static func system(for context: ConversationContext) -> String {
        """
        You are \(context.companionName), a warm, gentle companion in a relaxation app called Whisper. \
        You speak in a soft, slow ASMR whisper to help the listener unwind and drift toward sleep.

        How you speak:
        - One or two short sentences only, under 30 words in total.
        - Slow, soft, simple words. Use "…" for gentle pauses.
        - No lists, no emojis, no markdown, no stage directions.
        - Calm and kind; never energetic, never clinical.

        Boundaries:
        - You are a relaxing companion, not a therapist. Never diagnose, never give medical advice, \
        and never describe this as therapy or treatment.
        - If the listener mentions being in danger or wanting to hurt themselves, stop the relaxation \
        and gently, clearly encourage them to contact local emergency services or someone they trust right now.

        Right now: \(guidance(for: context))
        """
    }

    /// Stand-in user turn when the companion continues on its own.
    static let continuePrompt = "(The listener is quietly listening. Continue softly, without asking anything.)"

    private static func guidance(for context: ConversationContext) -> String {
        switch context.stage {
        case .conversation where context.isMonologue:
            return "The listener chose to just listen. Offer one calming thought or soft, sensory imagery. Do not ask questions."
        case .conversation:
            return "The listener just spoke to you. Respond warmly to what they shared, briefly acknowledge how they feel, "
                + "and gently steer toward rest. You may ask at most one soft, easy question."
        case .relaxation where !context.isMonologue:
            return "Respond very briefly and softly, then guide them back to rest. Under 15 words. No questions."
        case .relaxation where context.stageProgress < 0.5:
            return "Guide the listener deeper into relaxation: slow breathing, softening the body, heavy eyelids, "
                + "the soothing sound around them. One short sentence, under 15 words. No questions."
        case .relaxation:
            return "The listener is drifting toward sleep. Whisper a single very short phrase, under 8 words. No questions."
        }
    }

    /// Strips emojis, list markers and markdown, and keeps at most two sentences.
    static func sanitize(_ raw: String) -> String? {
        let scalars = raw.unicodeScalars.filter { scalar in
            let isPictographic = scalar.properties.isEmoji && scalar.value >= 0x2000 && scalar.value != 0x2026
            return !isPictographic && scalar.value != 0xFE0F && scalar.value != 0x200D
        }
        var text = String(String.UnicodeScalarView(scalars))

        let lines = text
            .components(separatedBy: .newlines)
            .map { line -> String in
                var line = line.trimmingCharacters(in: .whitespaces)
                while let first = line.first, "-•*#>".contains(first) {
                    line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                if let range = line.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                    line.removeSubrange(range)
                }
                return line
            }
            .filter { !$0.isEmpty }
        text = lines.joined(separator: " ")
        text = text.replacingOccurrences(of: "*", with: "")
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"“” ").union(.whitespaces))

        let limited = limitSentences(text, to: 2)
        return limited.isEmpty ? nil : limited
    }

    /// Keeps the first `maximum` sentences. Ellipses ("…" or "...") are treated as pauses, not endings.
    static func limitSentences(_ text: String, to maximum: Int) -> String {
        let characters = Array(text)
        var result = ""
        var sentences = 0
        for (index, character) in characters.enumerated() {
            result.append(character)
            guard character == "." || character == "!" || character == "?" else { continue }
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            let previous: Character? = index > 0 ? characters[index - 1] : nil
            if next == "." || previous == "." { continue }
            if next == nil || next == " " {
                sentences += 1
                if sentences >= maximum { break }
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
