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
                prose: L(
                    "monocle.app_bar_xref",
                    "The app bar shown in monocle is "
                        + "configured in"
                ),
                linkTitle: L(
                    "scroll_grid.app_bar_xref_link",
                    "Appearance ▸ App Bar"
                ),
                destination: .appearance
            )
        }
    }
}
