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
            // ONE caption for one picture. Both mounts draw
            // `PaletteSceneThumbnail` at `.panel`, so shipping
            // two English descriptions of it into ten catalogs
            // was two chances to describe the same drawing
            // differently (localization audit, 2026-08-16).
            caption: PaletteSceneCaption.panel
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
