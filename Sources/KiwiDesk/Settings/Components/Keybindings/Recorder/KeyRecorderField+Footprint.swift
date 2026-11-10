import SwiftUI

extension KeyRecorderField {
    /// Fixed width for trailing action icon slots (#264).
    static let iconSlotWidth: CGFloat = 20
    /// The chord label's least width, so recorders line up; a
    /// sided chord fits it in every catalog
    /// (`ChordGlyphsWidthTests`).
    static let labelMinWidth: CGFloat = 110

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
        // Read here: the guard's closure is Sendable.
        let shift = recorderSides == nil ? 0 : lead / 2
        HStack(spacing: 6) {
            slot
            if recorderSides != nil { slot }
            KeyRecorderField.recordWell(" ") {}
            slot
        }
        .hidden()
        .accessibilityHidden(true)
        // Its centre stays the well's, which an overlay on the
        // footprint centres on, the Sides slot leading it or not.
        .alignmentGuide(HorizontalAlignment.center) { size in
            size.width / 2 + shift
        }
    }

    /// The Sides slot and the gap after it.
    private var lead: CGFloat { KeyRecorderField.iconSlotWidth + 6 }

    private var slot: some View {
        Color.clear.frame(width: KeyRecorderField.iconSlotWidth)
    }
}
