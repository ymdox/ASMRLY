import SwiftUI

struct HomeView: View {
    let companion: Companion
    let onStart: (Ambience) -> Void

    @AppStorage("selectedAmbience") private var ambience: Ambience = .rain

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    CompanionCard(companion: companion)
                    AmbiencePicker(selection: $ambience)
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.top, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.l)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { startSection }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(Greeting.text())
                .font(Theme.Typography.greeting)
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Ready to wind down?")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var startSection: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button {
                onStart(ambience)
            } label: {
                Label("Start ASMR", systemImage: "moon.stars")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("Begins a twenty minute relaxing session with \(companion.name).")

            Text("For relaxation only. Whisper is not a medical or mental-health service.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Layout.screenPadding)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.s)
        .background(Theme.Colors.midnight.opacity(0.9).ignoresSafeArea())
    }
}

#Preview {
    HomeView(companion: .luna, onStart: { _ in })
}
