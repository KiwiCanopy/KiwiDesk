import KiwiDeskCore
import SwiftUI

/// The override count on the Space row's Customize glyph (#2674):
/// neutral ink, never red, which reads as an alert; dimmed while
/// a Floating Space's overrides all wait for a tiling layout;
/// absent with none. Hidden from VoiceOver: the button speaks
/// `spokenValue` instead, kept here so the two read one state.
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

    /// The badge in words, for the button's accessibility value.
    static func spokenValue(_ state: OverrideCellState) -> String {
        switch state {
        case .customize:
            return L("spaces.customize.a11y_none", "None")
        case .custom(let count):
            return L("spaces.overrides.custom", "%1$d custom", count)
        case .saved(let count):
            return L(
                "spaces.customize.a11y_saved",
                "%1$d saved — they apply when it tiles again",
                count
            )
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
