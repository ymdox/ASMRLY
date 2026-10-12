import SwiftUI

/// Full-screen live session. Layout only — all behaviour lives in `SessionManager`.
struct LiveSessionView: View {
    let session: SessionManager
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SessionBackground(reduceMotion: reduceMotion)

            VStack(spacing: Theme.Spacing.l) {
                SessionHeader(
                    companionName: session.companion.name,
                    elapsed: session.elapsed,
                    total: session.configuration.totalDuration
                )

                Spacer(minLength: Theme.Spacing.xs)

                CompanionOrb(activity: session.activity, reduceMotion: reduceMotion)

                Text(session.statusText)
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.lavender)
                    .contentTransition(.opacity)
                    .accessibilityLabel("\(session.companion.name) is \(session.statusText.lowercased())")
                    .accessibilityAddTraits(.updatesFrequently)

                TranscriptView(
                    lines: session.transcript,
                    liveText: session.liveUserText,
                    companionName: session.companion.name
                )

                Spacer(minLength: Theme.Spacing.xs)

                NoticeBanner(message: session.notice)

                SessionControlPanel(session: session, onEnd: endSession)
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.vertical, Theme.Spacing.m)
            .disabled(session.isEnding)
            .opacity(session.isEnding ? 0.5 : 1)

            if session.safetyTriggered {
                SafetySupportView(onClose: onClose)
                    .transition(.opacity)
            } else if session.phase == .completed, !session.isEnding {
                SessionEndView(
                    title: "Sleep well",
                    message: "Your session has gently come to an end.",
                    onClose: onClose
                )
                .transition(.opacity)
            } else if session.phase == .error {
                SessionEndView(
                    title: "Let's try again soon",
                    message: session.notice ?? SessionManager.voiceUnavailableMessage,
                    onClose: onClose
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: session.phase)
        .animation(.easeInOut(duration: 0.8), value: session.safetyTriggered)
        .animation(.easeInOut(duration: 0.6), value: session.activity)
        .animation(.easeInOut(duration: 0.6), value: session.notice)
        .persistentSystemOverlays(.hidden)
        .task {
            await session.start()
        }
        .onDisappear {
            session.teardown()
        }
    }

    private func endSession() {
        Task {
            await session.end()
            onClose()
        }
    }
}

#Preview {
    LiveSessionView(
        session: SessionManager(
            companion: .luna,
            ambience: .rain,
            configuration: .standard,
            mode: .justListen,
            canTalk: false,
            dependencies: .preview()
        ),
        onClose: {}
    )
}
