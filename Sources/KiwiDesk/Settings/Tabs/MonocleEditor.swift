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
            symbol: LayoutMode.monocle.glyph,
            // Answers "why no Wrap focus toggle here?" in place —
            // monocle's cycle always wraps (#168). A static line,
            // not a disabled Toggle (which would imply a setting
            // that does not exist).
            caption: L(
                "monocle.wrap_caption",
                "Focus always wraps at the ends in monocle."
            )
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
