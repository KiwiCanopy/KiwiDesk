import KiwiDeskCore
import SwiftUI

/// A dropdown row on the shared label axis: the visible label
/// sits in the label column and the menu button starts on the
/// control line, like every slider and segmented picker.
///
/// The row NAMES the control and gives its choice back as the
/// VALUE: `labelsHidden` drops a `.menu` picker's AX title (the
/// observation is `docs/design-decisions.md` ▸ a name replaces
/// the announcement), and a label alone would take the choice
/// away. So `spokenValue` is required — the selected option's
/// title, as the site knows it — and `nil` is for a control
/// whose state IS its value and survives a label — the login
/// row's `Toggle` — and nothing else, held by
/// `AnnouncedValueTests`' `nilSpokenValue` map.
struct DropdownRow<P: View>: View {
    let label: String
    /// The selected option's title, spoken as the control's
    /// value; `nil` only for a `Toggle`, whose on/off is kept.
    let spokenValue: String?
    /// Optional `?` popover (#94), label-adjacent.
    var help: String? = nil
    @ViewBuilder let picker: P

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(label: label, help: help)
        } control: {
            HStack {
                named(
                    picker
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.large)
                )
                Spacer()
            }
        }
    }

    // Applied AFTER `labelsHidden` — the order the Spaces mode
    // picker uses; before it, the name never reached the pop-up
    // on device (owner, #812 session 2).
    @ViewBuilder private func named<V: View>(_ picker: V) -> some View {
        if let spokenValue {
            picker
                .accessibilityLabel(label)
                .accessibilityValue(spokenValue)
        } else {
            picker.accessibilityLabel(label)
        }
    }
}
