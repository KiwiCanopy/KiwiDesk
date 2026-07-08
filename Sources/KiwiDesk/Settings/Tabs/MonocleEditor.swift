import KiwiDeskCore
import SwiftUI

/// Monocle's focus orientation. The indicator bar's look and its
/// per-layout overrides now live in the App Bar tab, shared with
/// scrolling.
struct MonocleEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            "Monocle",
            symbol: LayoutMode.monocle.glyph
        ) {
            Picker(
                "Focus orientation",
                selection: $model.config.settings.monocle
                    .orientation
            ) {
                Text("Horizontal")
                    .tag(MonocleParams.Orientation.horizontal)
                Text("Vertical")
                    .tag(MonocleParams.Orientation.vertical)
            }
            .pickerStyle(.segmented)
            Text(
                "The app bar shown in monocle is configured in "
                    + "the App Bar tab."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
