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
            // Not "everything a palette paints" — the scene
            // draws six of the twenty-five paths a palette
            // carries, and this phase is what grew it to
            // twenty-five. A caption labels what is shown.
            caption: L(
                "colors.scene.caption",
                "A sample of what a palette paints: the bar "
                    + "plate and its active item, the focus "
                    + "ring, and the drag ghost."
            )
        ) {
            PaletteSceneThumbnail(
                palette: ColorPalette(
                    name: "",
                    colors: ColorPaletteKeys.extract(
                        from: model.config.settings
                    )
                ),
                height: 190
            )
            .frame(maxWidth: .infinity)
        }
    }
}
