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
            // The column header's OWN key, not a twin: a second
            // key hands ten translators the same bare word with no
            // context (l10n audit 2026-08-11). The reuse is legal
            // because this chrome has ONE consumer, argued on
            // `OverridePickerRow` — the header above is always the
            // one this key names.
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

    /// What ticking the box MEANS — hover string and spoken hint
    /// are one sentence, never two that drift. A hint, not part of
    /// the label: the checkbox already announces checked/unchecked,
    /// and putting the meaning in the label would say the same
    /// thing twice and invert on the row about to be clicked.
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
