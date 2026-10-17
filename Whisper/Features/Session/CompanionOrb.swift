import SwiftUI

/// Soft glowing orb that breathes gently and pulses while the companion whispers.
struct CompanionOrb: View {
    let activity: CompanionActivity
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            orb(scale: scale(at: context.date.timeIntervalSinceReferenceDate))
        }
        .frame(width: 180, height: 180)
        .accessibilityHidden(true)
    }

    private func orb(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.lavender.opacity(glowOpacity))
                .blur(radius: 40)
                .scaleEffect(scale * 1.15)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.Colors.lavenderGlow,
                            Theme.Colors.lavender.opacity(0.55),
                            Theme.Colors.dusk.opacity(0.35),
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 4,
                        endRadius: 110
                    )
                )
                .frame(width: 140, height: 140)
                .scaleEffect(scale)
            if activity == .listening {
                Circle()
                    .strokeBorder(Theme.Colors.lavenderGlow.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 168, height: 168)
                    .scaleEffect(scale)
            }
        }
    }

    private var glowOpacity: Double {
        switch activity {
        case .whispering: 0.55
        case .listening: 0.45
        case .thinking: 0.35
        case .idle: 0.28
        }
    }

    private func scale(at time: TimeInterval) -> CGFloat {
        guard !reduceMotion else { return 1 }
        let value: Double
        switch activity {
        case .whispering: value = 1 + 0.06 * sin(time * 2.4) + 0.02 * sin(time * 5.3)
        case .listening: value = 1.03 + 0.02 * sin(time * 3)
        case .thinking: value = 1 + 0.025 * sin(time * 1.6)
        case .idle: value = 1 + 0.015 * sin(time * 0.8)
        }
        return CGFloat(value)
    }
}
