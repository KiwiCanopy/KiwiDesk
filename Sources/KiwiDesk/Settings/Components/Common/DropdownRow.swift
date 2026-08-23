import KiwiDeskCore
import SwiftUI

/// A dropdown row on the shared label axis: the visible label
/// sits in the label column and the menu button starts on the
/// control line, like every slider and segmented picker.
///
/// The row NAMES the control and gives its choice back as the
/// VALUE. This used to say the picker "keeps its own title for
/// accessibility — `labelsHidden` hides it visually only", and
/// on device it does not: General ▸ Language announced "menu,
/// 12 items, Deutsch" and never "Display language" (owner,
/// #812 device session 1, macOS 26). A label alone would then
/// take the choice away (it REPLACES the announcement — gui.md
/// ▸ the keyboard path), so `spokenValue` is required: the
/// selected option's title, as the site knows it. `nil` is for
/// a control whose state IS its value and survives a label —
/// the login row's `Toggle` — and nothing else.
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
                named(picker)
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.large)
                Spacer()
            }
        }
    }

    @ViewBuilder private func named(_ picker: P) -> some View {
        if let spokenValue {
            picker
                .accessibilityLabel(label)
                .accessibilityValue(spokenValue)
        } else {
            picker.accessibilityLabel(label)
        }
    }
}
