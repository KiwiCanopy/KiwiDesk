import KiwiDeskCore
import SwiftUI

/// The live-colours scene, moved from the section body into
/// the detail panel (#678 redesign spec) — the panel is where the
/// draft is watched, and this was always a standalone
/// illustration rather than a control's preview.
///
/// Deliberately NOT a new preview component:
/// `PaletteSceneThumbnail` already composes bar strip, ringed
/// window and drag ghost, and it already reads a colour
/// dictionary — so feeding it the staged config's own colours
/// turns the palette picker's tile into "what you are
/// running", with no second drawing to keep in step. The
/// redesign's preview rule is exactly this: recycle, never
/// rebuild from a mock.
struct PaletteScenePanel: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.currentScene,
            // The caption labels what is shown, and since #793
            // that is the full scene rather than a sample of
            // it: this mount takes `.panel` like Advanced
            // Colours' own, so the two pages cannot disagree
            // about what a palette paints. What it still does
            // NOT show is the four pointer states, which is
            // `PaletteSceneRoles.withheld`'s argument and not a
            // caption's to make.
            caption: L(
                "colors.scene.caption",
                "Both bars, the focused and unfocused rings "
                    + "with their state marks, and the drag "
                    + "ghost beside its drop zone."
            )
        ) {
            PaletteSceneThumbnail(
                palette: ColorPalette(
                    name: "",
                    colors: ColorPaletteKeys.extract(
                        from: model.config.settings
                    )
                ),
                height: 300,
                scene: .panel
            )
            .frame(maxWidth: .infinity)
        }
    }
}
