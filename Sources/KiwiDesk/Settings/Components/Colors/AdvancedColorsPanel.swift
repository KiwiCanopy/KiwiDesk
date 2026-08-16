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
                height: 300,
                scene: .panel
            )
            .frame(maxWidth: .infinity)
        }
    }

    /// Labels what IS drawn, and does not disclaim what is not.
    /// The four hover roles are absent because a still frame can
    /// draw a pointer state only as the resting one
    /// (`PaletteSceneRoles.withheld`); a caption saying so would
    /// teach the reader that a rule exists without teaching the
    /// rule, which is the trade `gui.md` settles in favour of
    /// labelling the picture.
    private var caption: String {
        L(
            "colors.advanced.scene.caption",
            "Both bars with their active and focused items, the "
                + "focused and unfocused rings with their state "
                + "marks, and the drag ghost beside its drop "
                + "zone."
        )
    }
}
