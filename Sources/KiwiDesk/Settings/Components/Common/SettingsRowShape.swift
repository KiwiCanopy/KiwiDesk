import SwiftUI

/// A labelled row's ARRANGEMENT, and the one place the settings
/// tree decides it (#678 turn 17a).
///
/// Wide enough, a row is a label in the shared column
/// (`SettingsMetrics.labelColumn`) with its control hanging off
/// that axis — which is what makes controls of one kind line up
/// down a whole section. Below the row breakpoint the label goes
/// ABOVE and the control takes the full width, because the
/// alternative at 820 pt is a segmented control that wraps or a
/// menu clipped to its chevron, and 17a's order forbids both:
/// preview first, then row layout, then chrome, and controls
/// never.
///
/// **The switch is `AnyLayout`, deliberately, not an `if`.** Both
/// arrangements draw the same two children, so the layout swap
/// keeps their identity — a menu stays open, a focused field
/// keeps focus, and the reflow animates instead of the row being
/// torn down and rebuilt as the user drags the window edge. An
/// `if stacked { VStack } else { HStack }` is two subtrees and
/// loses all three.
///
/// Every shared row shape routes through this
/// (`SettingsRowShapeTests` holds the label column's one
/// application site, so a row hand-framing `labelColumn` beside
/// it reds).
struct SettingsRowShape<Label: View, Control: View>: View {
    @Environment(\.settingsWidth) private var width
    @Environment(\.settingsLabelColumn) private var labelColumn
    @ViewBuilder let label: Label
    @ViewBuilder let control: Control

    var body: some View {
        let stacked = width.stacksRows
        // Default HStack spacing on the wide arm: the rows this
        // replaced were plain `HStack {}`, and the label axis is
        // shared app-wide, so a spacing of its own here would
        // move every section's control line by a few points.
        let layout =
            stacked
            ? AnyLayout(
                VStackLayout(alignment: .leading, spacing: 4)
            )
            : AnyLayout(HStackLayout())
        layout {
            label
                // `nil` when stacked — the modifier stays in the
                // chain either way rather than becoming an `if`,
                // which would put the label in a
                // `_ConditionalContent` and give away the
                // identity the `AnyLayout` above is here to
                // keep.
                .frame(
                    width: stacked ? nil : labelColumn,
                    alignment: .leading
                )
            control
        }
    }
}

/// The label side of a row: the text, plus the #94 `?` where the
/// row carries one. Extracted with the shape because the two
/// always ship together — every caller built this identical
/// `HStack(spacing: 4)` — and because the help button's
/// placement rule ("label-adjacent, inside the shared column")
/// is one decision, not six copies of one.
///
/// The text is drawn, not spoken. Every control that sits in
/// this shape names ITSELF — a slider through
/// `SettingsSlider.label`, a dropdown through its own title, a
/// segmented picker through its track — so read aloud as well
/// the label is the same words twice, once standing alone and
/// once as the control's name (the `LayoutPreviewPanel` ruling,
/// code review 2026-08-11, applied at the seam). The `?` stays
/// a rotor stop of its own; it is not the label's twin.
struct SettingsRowLabel: View {
    let label: String
    var help: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .lineLimit(1)
                .accessibilityHidden(true)
            if let help {
                HelpButton(explanation: help, subject: label)
            }
        }
    }
}
