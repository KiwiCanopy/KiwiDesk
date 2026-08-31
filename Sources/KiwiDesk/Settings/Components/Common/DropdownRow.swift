import KiwiDeskCore
import SwiftUI

/// Standard settings dropdown row: `labelsHidden` drops a `.menu`
/// picker's AX title, so the row NAMES the control and `spokenValue`
/// gives the choice back as the VALUE (`AnnouncedValueTests`).
struct DropdownRow<P: View>: View {
    let label: String
    /// Selected option's title, spoken as the value; `nil` only for
    /// a `Toggle`, whose on/off state survives a label.
    let spokenValue: String?
    /// Optional help popover text (#94).
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
