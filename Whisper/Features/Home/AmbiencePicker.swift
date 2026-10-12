import SwiftUI

struct AmbiencePicker: View {
    @Binding var selection: Ambience

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: Theme.Spacing.s)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Ambience")
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                ForEach(Ambience.allCases) { ambience in
                    AmbienceChip(ambience: ambience, isSelected: ambience == selection) {
                        selection = ambience
                    }
                }
            }
        }
    }
}

private struct AmbienceChip: View {
    let ambience: Ambience
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: ambience.symbolName)
                    .font(.title3)
                Text(ambience.displayName)
                    .font(Theme.Typography.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(isSelected ? Theme.Colors.lavenderMuted : Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Colors.lavender.opacity(0.7) : Theme.Colors.stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: isSelected)
        .accessibilityLabel("\(ambience.displayName) ambience")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
