import SwiftUI

/// Design tokens for Whisper's calm, low-saturation bedtime aesthetic.
enum Theme {
    enum Colors {
        static let midnight = Color(red: 0.039, green: 0.051, blue: 0.110)
        static let navy = Color(red: 0.086, green: 0.110, blue: 0.212)
        static let dusk = Color(red: 0.145, green: 0.153, blue: 0.282)

        static let lavender = Color(red: 0.720, green: 0.680, blue: 0.920)
        static let lavenderMuted = Color(red: 0.720, green: 0.680, blue: 0.920).opacity(0.35)
        static let lavenderGlow = Color(red: 0.820, green: 0.790, blue: 0.960)

        /// Warm off-white for primary text.
        static let textPrimary = Color(red: 0.960, green: 0.930, blue: 0.880)
        static let textSecondary = Color(red: 0.960, green: 0.930, blue: 0.880).opacity(0.68)
        static let textTertiary = Color(red: 0.960, green: 0.930, blue: 0.880).opacity(0.45)
        /// Text placed on top of the lavender accent.
        static let textOnAccent = Color(red: 0.070, green: 0.075, blue: 0.160)

        static let surface = Color.white.opacity(0.055)
        static let surfaceRaised = Color.white.opacity(0.09)
        static let stroke = Color.white.opacity(0.08)

        static let background = LinearGradient(
            colors: [navy, midnight],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let small: CGFloat = 16
        static let medium: CGFloat = 24
        static let large: CGFloat = 32
    }

    /// All fonts are built from text styles so they scale with Dynamic Type.
    enum Typography {
        static let greeting = Font.system(.largeTitle, design: .rounded, weight: .light)
        static let title = Font.system(.title2, design: .rounded, weight: .regular)
        static let headline = Font.system(.headline, design: .rounded, weight: .medium)
        static let body = Font.system(.body, design: .rounded, weight: .regular)
        static let whisper = Font.system(.title3, design: .serif, weight: .light).italic()
        static let caption = Font.system(.footnote, design: .rounded, weight: .regular)
        static let label = Font.system(.subheadline, design: .rounded, weight: .medium)
        static let timer = Font.system(.subheadline, design: .rounded, weight: .regular).monospacedDigit()
        static let button = Font.system(.title3, design: .rounded, weight: .semibold)
    }

    enum Layout {
        /// Apple's minimum comfortable tap target.
        static let minTapTarget: CGFloat = 44
        static let primaryButtonHeight: CGFloat = 64
        static let screenPadding: CGFloat = 24
    }
}

extension View {
    /// Soft translucent card used across the app.
    func cardStyle(cornerRadius: CGFloat = Theme.Radius.large) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Theme.Colors.stroke, lineWidth: 1)
                )
        )
    }
}
