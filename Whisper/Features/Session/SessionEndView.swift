import SwiftUI

struct SessionEndView: View {
    let title: String
    let message: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.Colors.midnight.opacity(0.92).ignoresSafeArea()
            VStack(spacing: Theme.Spacing.l) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.Colors.lavender)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Theme.Typography.greeting)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Done", action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, Theme.Spacing.m)
            }
            .padding(Theme.Layout.screenPadding)
        }
    }
}
