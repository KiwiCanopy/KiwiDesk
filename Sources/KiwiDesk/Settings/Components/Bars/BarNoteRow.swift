import SwiftUI

/// An inline note under a Bars row, set in the control column
/// (#1517): what a choice costs, said where it is chosen.
struct BarNoteRow: View {
    let text: String

    var body: some View {
        SettingsRowShape {
            BarRowIndent()
        } control: {
            // A plain caption, as `FitGapsAction`'s inline reason
            // is: one shape for a note under a row.
            Text(text)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The empty label a control-column-only row takes, so it lines
/// up with its row above at every width.
struct BarRowIndent: View {
    var body: some View {
        Color.clear
            .frame(height: 0)
            .accessibilityHidden(true)
    }
}
