import SwiftUI

/// Large, soft lavender capsule button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.button)
            .foregroundStyle(Theme.Colors.textOnAccent)
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.primaryButtonHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.Colors.lavender)
                    .shadow(color: Theme.Colors.lavender.opacity(0.35), radius: 24, y: 8)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// Quiet secondary button used for low-emphasis actions.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapTarget)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
