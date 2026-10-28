import KiwiDeskCore
import SwiftUI

/// The `Simple | Advanced` segment at the header's trailing edge
/// (#2737): the same control in the same place on both roots. Its
/// label says which root shows; no hue marks the mode.
struct SettingsRootSwitch: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SegmentedPicker(
            selection: $model.settingsRoot,
            options: [
                (Self.simpleTitle, SettingsRoot.simple),
                (Self.advancedTitle, SettingsRoot.advanced),
            ]
        )
        .fixedSize()
        .accessibilityLabel(
            L("settings.root.ax", "Settings to show")
        )
    }

    @MainActor static var simpleTitle: String {
        L("settings.root.simple", "Simple")
    }

    /// Also the link title of every "kept in Advanced" sentence.
    @MainActor static var advancedTitle: String {
        L("settings.root.advanced", "Advanced")
    }
}
