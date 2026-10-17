import SwiftUI

/// Debug-only card on Home showing whether OpenAI and ElevenLabs actually work with the keys in this build.
struct ConnectionStatusCard: View {
    let checks: [ProviderCheck]
    let isChecking: Bool
    let onRecheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("Connection check (debug only)")
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                if isChecking {
                    ProgressView().tint(Theme.Colors.lavender)
                } else {
                    Button("Re-check", action: onRecheck)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.lavender)
                        .frame(minHeight: Theme.Layout.minTapTarget)
                }
            }
            ForEach(checks) { check in
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("\(check.isWorking ? "✅" : "❌") \(check.name)")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(check.detail)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: Theme.Radius.medium)
    }
}
