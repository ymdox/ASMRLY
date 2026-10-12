import SwiftUI

struct SessionHeader: View {
    let companionName: String
    let elapsed: TimeInterval
    let total: TimeInterval

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(companionName)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("ASMR session")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            Text("\(Self.format(elapsed)) / \(Self.format(total))")
                .font(Theme.Typography.timer)
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityLabel("Session time \(Self.spoken(elapsed)) of \(Self.spoken(total))")
        }
    }

    private static func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func spoken(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return "\(seconds / 60) minutes \(seconds % 60) seconds"
    }
}
