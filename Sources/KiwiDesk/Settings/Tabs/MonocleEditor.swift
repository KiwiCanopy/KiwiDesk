import KiwiDeskCore
import SwiftUI

/// Monocle's focus orientation. The indicator bar's look and its
/// per-layout overrides now live in the App Bar tab, shared with
/// scrolling.
struct MonocleEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            L("layout.monocle.name", "Monocle"),
            symbol: LayoutMode.monocle.glyph
        ) {
            MonocleSchematic(
                orientation: model.config.settings.monocle
                    .orientation
            )
            SegmentedPicker(
                L(
                    "monocle.focus_orientation",
                    "Focus orientation"
                ),
                selection: $model.config.settings.monocle
                    .orientation,
                options: [
                    (
                        L(
                            "scroll_grid.horizontal",
                            "Horizontal"
                        ),
                        MonocleParams.Orientation.horizontal
                    ),
                    (
                        L("scroll_grid.vertical", "Vertical"),
                        .vertical
                    ),
                ]
            )
            Divider()
            // Monocle is a carousel, so this defaults on (unlike
            // the linear scrolling/track wrap). Off = focus stops
            // at the first/last window. Reuses the shared
            // "Wrap focus" string.
            Toggle(
                L("scroll_grid.wrap_focus", "Wrap focus"),
                isOn: $model.config.settings.monocle.wrapFocus
            )
            Divider()
            PlacementPicker(
                placement: $model.config.settings.monocle
                    .newWindowPlacement
            )
            CrossReferenceRow(
                // Monocle has no schematic, so this row is where
                // its app-bar presence surfaces: live On/Off
                // state, with the toggle owned by the App Bar tab.
                prose: L(
                    "monocle.app_bar_xref_state",
                    "The monocle app bar (currently %1$@) is "
                        + "configured in",
                    barState
                ),
                linkTitle: L(
                    "scroll_grid.app_bar_xref_link",
                    "App Bar"
                ),
                destination: .appBar
            )
        }
    }

    private var barState: String {
        model.config.settings.monocle.appBar.enabled
            ? L("common.on", "on") : L("common.off", "off")
    }
}
