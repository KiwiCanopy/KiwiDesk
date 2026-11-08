import SwiftUI

extension KeyRecorderField {
    /// The empty field's footprint, drawn hidden, so a row in a
    /// shortcut list that holds no recorder lines its trailing
    /// controls up with the rows that do (#1655). Built from the
    /// field's own slots and button metrics, the Sides slot
    /// included while sides are told apart (#2614).
    static var footprint: some View { RecorderFootprint() }
}

/// The footprint as a view, so it reads `\.recorderSides` as the
/// field does.
private struct RecorderFootprint: View {
    @Environment(\.recorderSides) private var recorderSides

    var body: some View {
        HStack(spacing: 6) {
            slot
            if recorderSides != nil { slot }
            Button {
            } label: {
                Text(verbatim: " ")
                    .frame(minWidth: KeyRecorderField.labelMinWidth)
                    .monospaced()
            }
            .settingsActionButton()
            .controlSize(.regular)
            slot
        }
        .hidden()
        .accessibilityHidden(true)
    }

    private var slot: some View {
        Color.clear.frame(width: KeyRecorderField.iconSlotWidth)
    }
}
