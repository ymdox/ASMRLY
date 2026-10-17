import SwiftUI
import UIKit

/// Mode toggle, ambience volume and the Pause / Microphone / End row.
struct SessionControlPanel: View {
    let session: SessionManager
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ModeToggle(mode: session.mode, canTalk: session.canTalk) { mode in
                session.setMode(mode)
            }

            if !session.canTalk {
                MicrophoneOffNotice(companionName: session.companion.name)
            } else if let hint = session.talkHint {
                Text(hint)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: hint)
            }

            if session.ambience != .none {
                AmbienceVolumeSlider(value: session.ambienceVolume) { volume in
                    session.setAmbienceVolume(volume)
                }
            }

            HStack(alignment: .center) {
                RoundIconButton(
                    systemName: session.isPaused ? "play.fill" : "pause.fill",
                    title: session.isPaused ? "Resume" : "Pause"
                ) {
                    session.togglePause()
                }
                .disabled(!session.canPause)

                Spacer()

                MicrophoneButton(
                    isListening: session.activity == .listening,
                    isEnabled: session.isMicrophoneEnabled,
                    companionName: session.companion.name,
                    onStart: { session.beginListening() },
                    onStop: { session.finishListening() }
                )

                Spacer()

                RoundIconButton(systemName: "xmark", title: "End", action: onEnd)
                    .accessibilityLabel("End session")
            }
        }
    }
}

/// Explains why Talk is off and links to Settings to turn the microphone on.
private struct MicrophoneOffNotice: View {
    let companionName: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text("Microphone or speech recognition is off, so \(companionName) keeps you company in Just Listen mode.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
            if let settings = URL(string: UIApplication.openSettingsURLString) {
                Button("Turn on in Settings, then start a new session") {
                    openURL(settings)
                }
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.lavender)
                .frame(minHeight: Theme.Layout.minTapTarget)
            }
        }
    }
}

struct ModeToggle: View {
    let mode: InteractionMode
    let canTalk: Bool
    let onSelect: (InteractionMode) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(InteractionMode.allCases) { option in
                let isSelected = option == mode
                let isAvailable = option == .justListen || canTalk
                Button {
                    onSelect(option)
                } label: {
                    Text(option.title)
                        .font(Theme.Typography.label)
                        .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapTarget)
                        .background(Capsule().fill(isSelected ? Theme.Colors.lavenderMuted : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable)
                .opacity(isAvailable ? 1 : 0.5)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(isAvailable ? "" : "Microphone access is off.")
            }
        }
        .padding(Theme.Spacing.xxs)
        .background(Capsule().fill(Theme.Colors.surface))
        .animation(.easeInOut(duration: 0.25), value: mode)
    }
}

struct AmbienceVolumeSlider: View {
    let value: Float
    let onChange: (Float) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "speaker.fill")
                .accessibilityHidden(true)
            Slider(
                value: Binding(get: { Double(value) }, set: { onChange(Float($0)) }),
                in: 0...1
            )
            .accessibilityLabel("Ambience volume")
            .accessibilityValue("\(Int((value * 100).rounded())) percent")
            Image(systemName: "speaker.wave.3.fill")
                .accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(Theme.Colors.textTertiary)
        .frame(minHeight: Theme.Layout.minTapTarget)
    }
}

struct RoundIconButton: View {
    let systemName: String
    let title: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: systemName)
                    .font(.title3)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.Colors.surfaceRaised))
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .foregroundStyle(Theme.Colors.textSecondary)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Tap to start / tap to stop, or press and hold to talk and release to send.
struct MicrophoneButton: View {
    let isListening: Bool
    let isEnabled: Bool
    let companionName: String
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var pressStartedAt: Date?
    @State private var wasListeningAtPress = false

    private static let holdThreshold: TimeInterval = 0.4

    var body: some View {
        ZStack {
            Circle()
                .fill(isListening ? Theme.Colors.lavender : Theme.Colors.surfaceRaised)
                .frame(width: 84, height: 84)
                .overlay(Circle().strokeBorder(Theme.Colors.lavender.opacity(0.5), lineWidth: 1))
                .shadow(color: Theme.Colors.lavender.opacity(isListening ? 0.5 : 0), radius: 20)
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.title)
                .foregroundStyle(isListening ? Theme.Colors.textOnAccent : Theme.Colors.textPrimary)
        }
        .opacity(isEnabled ? 1 : 0.35)
        .contentShape(Circle())
        .gesture(pressGesture, including: isEnabled ? .all : .none)
        .animation(.easeInOut(duration: 0.3), value: isListening)
        .sensoryFeedback(.impact(weight: .light), trigger: isListening)
        .accessibilityElement()
        .accessibilityLabel(isListening ? "Stop talking" : "Talk to \(companionName)")
        .accessibilityHint(isEnabled ? "Double tap to start or stop speaking." : "Available in Talk mode during the conversation.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            guard isEnabled else { return }
            isListening ? onStop() : onStart()
        }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard pressStartedAt == nil else { return }
                pressStartedAt = .now
                wasListeningAtPress = isListening
                if !isListening { onStart() }
            }
            .onEnded { _ in
                let heldFor = pressStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
                pressStartedAt = nil
                // Tap while listening stops; a long hold stops on release; a short tap keeps listening.
                if wasListeningAtPress || heldFor >= Self.holdThreshold {
                    onStop()
                }
            }
    }
}
