import KiwiDeskCore
import SwiftUI

/// The `Simple | Advanced` segment at the header's trailing edge
/// (#2737): the same control in the same place on both roots. Its
/// label says which root shows; no hue marks the mode. A tap on
/// the selected segment must still reach `pickRoot`: after a
/// landing it is how Advanced is stored (`SegmentedPicker.select`
/// does not skip the selected value).
struct SettingsRootSwitch: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SegmentedPicker(
            spokenLabel: L("settings.root.ax", "Settings to show"),
            selection: Binding(
                get: { model.settingsRoot },
                set: { model.pickRoot($0) }
            ),
            options: [
                (Self.simpleTitle, SettingsRoot.simple),
                (Self.advancedTitle, SettingsRoot.advanced),
            ]
        )
        .fixedSize()
    }

    @MainActor static var simpleTitle: String {
        L("settings.root.simple", "Simple")
    }

    /// Also the link title of every "kept in Advanced" sentence.
    @MainActor static var advancedTitle: String {
        L("settings.root.advanced", "Advanced")
    }
}
