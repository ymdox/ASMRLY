import SwiftUI

/// Soft, non-technical status message (e.g. voice unavailable).
struct NoticeBanner: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .frame(maxWidth: .infinity)
                .cardStyle(cornerRadius: Theme.Radius.small)
                .transition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
