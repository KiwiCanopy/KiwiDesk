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
                .frame(
                    width: stacked ? nil : labelColumn,
                    alignment: .leading
                )
            control
        }
    }
}

/// Row label container displaying text and optional help button (#94,
/// `LayoutPreviewPanel`).
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
