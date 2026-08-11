import KiwiDeskCore
import SwiftUI

/// The trailing OVERRIDE column's checkbox, split from
/// `AppBarOverrideControls` at the §2.1 ceiling. One control and
/// the one sentence explaining it — the sentence being shared
/// between the hover string and the spoken hint is the reason it
/// is a property rather than two inline literals.
extension OverrideChrome {
    /// The trailing OVERRIDE checkbox: checked means this row
    /// overrides the layout default (owner call 2026-08-04). Bound
    /// straight to `isOn`, so the tick agrees with the row's other
    /// "engaged" signals — the left accent bar, the tint, and the
    /// live control all appear together on a checked (overriding)
    /// row, and ticking-to-customize is the native inspector idiom.
    ///
    /// It draws no visible label — the column header names the
    /// whole column — so it authors one as an `.accessibilityLabel`
    /// (#678 Phase 4 pass 10; the `app_rules.space` / `.float`
    /// menus are the same case). Without it VoiceOver reads a bare
    /// "checkbox": the tick's state is announced, the thing it is
    /// the state OF is not.
    ///
    /// Label and hint carry different halves on purpose. The
    /// checkbox already announces checked or unchecked, so the
    /// sentence beside it is not the state — it is what the state
    /// MEANS, which is a hint's job. Putting it in the label would
    /// have VoiceOver read "Overriding the global value, checked",
    /// which says the same thing twice and inverts on the row the
    /// user is about to click.
    var overrideCheckbox: some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.checkbox)
            // The column header's OWN key, not a twin of it: this
            // checkbox sits under `SpaceOverrideRows`' visible
            // "Override" header, so a second key would hand ten
            // translators the same bare word with no context and
            // let VoiceOver announce a noun the header doesn't
            // show (localization audit, 2026-08-11).
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

    /// What ticking the box means, in one place: the hover string
    /// and the spoken hint are the same sentence, never two that
    /// can drift.
    var overrideStateSentence: String {
        isOn.wrappedValue
            ? L(
                "app_bar.override.on.help",
                "Overriding the global value"
            )
            : L(
                "app_bar.override.off.help",
                "Inheriting the global value"
            )
    }
}
