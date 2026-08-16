import KiwiDeskCore
import SwiftUI

/// Advanced Colours' detail panel (#793): every colour at once,
/// in one scene, drawn from the draft.
///
/// The area edits twenty-five colours across four groups, and
/// until now each row's effect was visible only on its own group
/// preview — so the composite question, *do these work together*,
/// could not be asked without saving and looking at the desktop.
/// Four separate group previews cannot answer it in principle:
/// the accent ladder, the two rings, the state marks and the drag
/// pair are judged against each other.
///
/// The scene is `PaletteSceneThumbnail` at `.panel`, which is
/// also what the palette shelf and Colours & Motion draw — one
/// renderer, three mounts, so the shelf and the page can never
/// disagree about what a palette paints. `PaletteSceneRoles` is
/// the census of what it shows.
struct AdvancedColorsPanel: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.advancedColors.everyColorScene,
            caption: caption
        ) {
            PaletteSceneThumbnail(
                palette: ColorPalette(
                    name: "",
                    colors: ColorPaletteKeys.extract(
                        from: model.config.settings
                    )
                ),
                // No height: the panel scene derives its own
                // from its rows (`panelHeight`). Passing one
                // here is what let the drawing exceed its frame.
                scene: .panel
            )
            .frame(maxWidth: .infinity)
        }
    }

    /// The shared caption — see `PaletteSceneCaption`.
    private var caption: String { PaletteSceneCaption.panel }
}
