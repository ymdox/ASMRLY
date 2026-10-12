import SwiftUI

struct CompanionCard: View {
    let companion: Companion

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.Colors.lavenderGlow, Theme.Colors.lavender.opacity(0.25)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 36
                    )
                )
                .frame(width: 64, height: 64)
                .shadow(color: Theme.Colors.lavender.opacity(0.4), radius: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Your companion")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text(companion.name)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(companion.tagline.capitalizedFirstLetter)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your companion: \(companion.name), \(companion.tagline)")
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        self.prefix(1).uppercased() + self.dropFirst()
    }
}
