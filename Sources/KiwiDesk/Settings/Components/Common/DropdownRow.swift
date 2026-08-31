import KiwiDeskCore
import SwiftUI

/// Standard settings dropdown row with label and accessibility value
/// (`AnnouncedValueTests`).
struct DropdownRow<P: View>: View {
    let label: String
    /// Selected option title spoken as accessibility value.
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
