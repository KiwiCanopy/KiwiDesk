import KiwiDeskCore
import SwiftUI

/// Trailing override column checkbox control
/// (`OverrideChrome`, `OverrideControls`).
extension OverrideChrome {
    /// Trailing override toggle with VoiceOver accessibility labels
    /// (`OverridePickerRow`, `SettingsMetrics.overrideStateColumn`,
    /// #678 Phase 4).
    var overrideCheckbox: some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.checkbox)
            .accessibilityLabel(
                L("space_override.override_column", "Override")
            )
            .accessibilityHint(overrideStateSentence)
            .help(overrideStateSentence)
            .frame(
                width: SettingsMetrics.overrideStateColumn,
                alignment: .center
            )
    }

    /// Localized explanation of override state shared by hover and
    /// VoiceOver hint.
    var overrideStateSentence: String {
        isOn.wrappedValue
            ? L(
                "space_override.on.help",
                "Overriding the global value"
            )
            : L(
                "space_override.off.help",
                "Inheriting the global value"
            )
    }
}
