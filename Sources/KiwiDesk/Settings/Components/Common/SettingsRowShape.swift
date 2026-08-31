import SwiftUI

/// Layout container switching between inline and stacked row layouts
/// (`SettingsMetrics.labelColumn`, `SettingsRowShapeTests`, #678 turn 17a).
///
/// Uses `AnyLayout` to preserve view identity and focus across window resize.
struct SettingsRowShape<Label: View, Control: View>: View {
    @Environment(\.settingsWidth) private var width
    @Environment(\.settingsLabelColumn) private var labelColumn
    @ViewBuilder let label: Label
    @ViewBuilder let control: Control

    var body: some View {
        let stacked = width.stacksRows
        let layout =
            stacked
            ? AnyLayout(
                VStackLayout(alignment: .leading, spacing: 4)
            )
            : AnyLayout(HStackLayout())
        layout {
            label
                // `nil` when stacked — the modifier stays in the
                // chain rather than becoming an `if`, which would
                // wrap the label in `_ConditionalContent` and give
                // away the identity `AnyLayout` is here to keep.
                .frame(
                    width: stacked ? nil : labelColumn,
                    alignment: .leading
                )
            control
        }
    }
}

/// Row label container displaying text and optional help button
/// (#94). The text is drawn, not spoken: every control in this
/// shape names ITSELF, so read aloud as well the label would be
/// the same words twice (the `LayoutPreviewPanel` ruling, code
/// review 2026-08-11, applied at the seam).
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
