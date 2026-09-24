import SwiftUI

/// An inline note under a Bars row, set in the control column
/// (#1517): what a choice costs, said where it is chosen.
struct BarNoteRow: View {
    let text: String

    var body: some View {
        SettingsRowShape {
            BarRowIndent()
        } control: {
            Label {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
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
