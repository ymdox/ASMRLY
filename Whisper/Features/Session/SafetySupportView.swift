import SwiftUI

/// Replaces the immersive session when the user mentions crisis or self-harm.
/// Calm, short, and points to real people — Whisper is not a support service.
struct SafetySupportView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.Colors.midnight.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Image(systemName: "heart")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Theme.Colors.lavender)
                        .accessibilityHidden(true)

                    Text("Let's pause here")
                        .font(Theme.Typography.greeting)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("It sounds like you might be going through something really painful. You deserve support from a real person right now.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("If you're in danger, please contact your local emergency services, or reach out to someone you trust.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    VStack(spacing: Theme.Spacing.s) {
                        if let crisisLine = URL(string: "tel:988") {
                            Link(destination: crisisLine) {
                                Label("Call or text 988 (US & Canada)", systemImage: "phone")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityHint("Calls the 988 Suicide and Crisis Lifeline.")
                        }
                        if let helplines = URL(string: "https://findahelpline.com") {
                            Link(destination: helplines) {
                                Label("Find a helpline in your country", systemImage: "globe")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        Button("Close", action: onClose)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.top, Theme.Spacing.s)
                }
                .padding(Theme.Layout.screenPadding)
                .padding(.top, Theme.Spacing.xl)
            }
        }
    }
}

#Preview {
    SafetySupportView(onClose: {})
}
