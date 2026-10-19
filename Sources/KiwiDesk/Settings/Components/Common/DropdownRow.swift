import KiwiDeskCore
import SwiftUI

/// Standard settings dropdown row: `labelsHidden` drops a `.menu`
/// picker's AX title, so the row NAMES the control and `spokenValue`
/// gives the choice back as the VALUE (`AnnouncedValueTests`). The
/// menu trails at its natural width, like the stepper (#2439).
struct DropdownRow<P: View, T: View>: View {
    let label: String
    /// Selected option's title, spoken as the value. Required: an
    /// on/off control takes `ToggleRow`, never this row (#2032).
    let spokenValue: String
    /// Optional help popover text (#94).
    var help: String? = nil
    @ViewBuilder let picker: P
    /// A control beside the pop-up, sharing its row (#2324's
    /// Compare and Copy…).
    @ViewBuilder var trailing: T

    var body: some View {
        SettingsRowShape(labelFills: true) {
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
                    .fixedSize()
                    .accessibilityLabel(label)
                    .accessibilityValue(spokenValue)
                trailing
            }
        }
    }
}

extension DropdownRow where T == EmptyView {
    init(
        label: String,
        spokenValue: String,
        help: String? = nil,
        @ViewBuilder picker: () -> P
    ) {
        self.init(
            label: label,
            spokenValue: spokenValue,
            help: help,
            picker: picker,
            trailing: { EmptyView() }
        )
    }
}
