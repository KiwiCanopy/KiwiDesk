import SwiftUI

extension KeyRecorderField {
    /// The empty field's footprint, drawn hidden, so a row in a
    /// shortcut list that holds no recorder lines its trailing
    /// controls up with the rows that do (#1655). Built from the
    /// field's own slots and button metrics.
    static var footprint: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: iconSlotWidth)
            Button {
            } label: {
                Text(verbatim: " ").frame(minWidth: 110).monospaced()
            }
            .settingsActionButton()
            .controlSize(.regular)
            Color.clear.frame(width: iconSlotWidth)
        }
        .hidden()
        .accessibilityHidden(true)
    }
}
