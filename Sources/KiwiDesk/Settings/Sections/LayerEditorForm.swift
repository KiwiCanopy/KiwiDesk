import KiwiDeskCore
import SwiftUI

/// The layer editor's form, shared by the add and edit popovers
/// (#3263) so the two draw one label column and one caption.
@MainActor
enum LayerEditorForm {
    static let width: CGFloat = 340

    static func grid(@ViewBuilder rows: () -> some View) -> some View {
        Grid(
            alignment: .leadingFirstTextBaseline,
            horizontalSpacing: 10,
            verticalSpacing: 8
        ) {
            rows()
        }
    }

    /// One labelled row. The label is drawn, not spoken: every
    /// control here names itself (#812).
    static func row(
        _ label: String,
        @ViewBuilder control: () -> some View
    ) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
                .accessibilityHidden(true)
            control()
        }
    }

    static func caption(_ text: String, refused: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(
                refused ? SettingsTheme.danger : SettingsTheme.ink3
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Applies to is drawn where there is a second profile to name.
    static func offersReach(_ reading: RuleReachReading) -> Bool {
        reading.profiles.count + reading.unreadable.count >= 2
    }
}
