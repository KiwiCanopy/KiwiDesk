import KiwiDeskCore
import SwiftUI

/// Standard settings dropdown row: `labelsHidden` drops a `.menu`
/// picker's AX title, so the row NAMES the control and `spokenValue`
/// gives the choice back as the VALUE (`AnnouncedValueTests`).
struct DropdownRow<P: View>: View {
    let label: String
    /// Selected option's title, spoken as the value. Required: an
    /// on/off control takes `ToggleRow`, never this row (#2032).
    let spokenValue: String
    /// Optional help popover text (#94).
    var help: String? = nil
    @ViewBuilder let picker: P

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(label: label, help: help)
        } control: {
            HStack {
                // Named AFTER `labelsHidden` — the order the Spaces
                // mode picker uses; before it, the name never
                // reached the pop-up on device (owner, #812).
                picker
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .neutralMenuLabel()
                    .controlSize(.large)
                    .accessibilityLabel(label)
                    .accessibilityValue(spokenValue)
                Spacer()
            }
        }
    }
}
