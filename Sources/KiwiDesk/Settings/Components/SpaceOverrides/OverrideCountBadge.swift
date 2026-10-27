import SwiftUI

/// The override count on the Space row's Customize glyph (#2674):
/// neutral ink, never red, which reads as an alert; dimmed while
/// a Floating Space's overrides all wait for a tiling layout;
/// absent with none. Drawn only — the button speaks the count.
struct OverrideCountBadge: View {
    let state: OverrideCellState

    var body: some View {
        switch state {
        case .customize:
            EmptyView()
        case .custom(let count):
            badge(count)
        case .saved(let count):
            badge(count).opacity(0.45)
        }
    }

    private func badge(_ count: Int) -> some View {
        Text(count.formatted())
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(SettingsTheme.sunken)
            .padding(.horizontal, 3)
            .frame(minWidth: 13, minHeight: 13)
            .background(Capsule().fill(SettingsTheme.ink2))
            .accessibilityHidden(true)
    }
}
