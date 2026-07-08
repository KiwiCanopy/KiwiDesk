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
            SegmentedPicker(
                "Focus orientation",
                selection: $model.config.settings.monocle
                    .orientation,
                options: [
                    (
                        "Horizontal",
                        MonocleParams.Orientation.horizontal
                    ),
                    ("Vertical", .vertical),
                ]
            )
            Text(
                "The app bar shown in monocle is configured in "
                    + "the App Bar tab."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
