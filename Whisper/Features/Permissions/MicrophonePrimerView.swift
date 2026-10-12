import SwiftUI

/// Shown before the system permission prompts so the request never comes out of nowhere.
struct MicrophonePrimerView: View {
    let onContinue: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Image(systemName: "mic.circle")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(Theme.Colors.lavender)
                    .accessibilityHidden(true)

                Text("Talk with Whisper")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Your microphone is only used during an active session when you choose to speak.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: Theme.Spacing.s) {
                    Button("Continue", action: onContinue)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Not now, I'll just listen", action: onNotNow)
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, Theme.Spacing.s)
            }
            .padding(Theme.Layout.screenPadding)
            .padding(.top, Theme.Spacing.m)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.navy)
        .presentationCornerRadius(Theme.Radius.large)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        MicrophonePrimerView(onContinue: {}, onNotNow: {})
    }
}
