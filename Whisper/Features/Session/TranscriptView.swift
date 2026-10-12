import SwiftUI

/// The last one or two lines, softly fading in and out. Deliberately not a chat log.
struct TranscriptView: View {
    let lines: [TranscriptLine]
    let liveText: String?
    let companionName: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                let isLatest = index == lines.count - 1
                Text(line.text)
                    .font(line.speaker == .companion ? Theme.Typography.whisper : Theme.Typography.body)
                    .foregroundStyle(color(for: line.speaker).opacity(isLatest ? 1 : 0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                    .accessibilityLabel(line.speaker == .companion ? "\(companionName): \(line.text)" : "You: \(line.text)")
            }

            if let liveText, !liveText.isEmpty {
                Text(liveText)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .transition(.opacity)
                    .accessibilityLabel("You: \(liveText)")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .animation(.easeInOut(duration: 1.2), value: lines)
        .animation(.easeInOut(duration: 0.3), value: liveText)
    }

    private func color(for speaker: TranscriptLine.Speaker) -> Color {
        speaker == .companion ? Theme.Colors.textPrimary : Theme.Colors.textTertiary
    }
}
