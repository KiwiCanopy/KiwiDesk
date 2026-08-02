import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Colours & Motion (#678 Phase 3, turn 12a): the
/// whole of the Simple colour story. A shelf of palettes applied
/// as a one-time paint, one scene showing what the current colours
/// actually look like, and the Motion card.
///
/// A Simple user meets six colour roles here, not twenty-five —
/// the per-element page is its own area, and "Save current colors
/// as…" on the shelf is the one bridge back from it.
struct ColorsMotionSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaletteShelf(model: model)
                currentScene
                MotionCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    /// The live-colours scene. Deliberately NOT a new preview
    /// component: `PaletteSceneThumbnail` already composes bar
    /// strip, ringed window and drag ghost, and it already reads
    /// a colour dictionary — so feeding it the staged config's
    /// own colours turns the palette picker's tile into "what you
    /// are running", with no second drawing to keep in step. The
    /// redesign's preview rule is exactly this: recycle, never
    /// rebuild from a mock.
    ///
    /// A standalone illustration rather than a control's preview,
    /// so it is centered with its caption below — unlike the four
    /// group previews on Advanced Colours, which lead their rows.
    private var currentScene: some View {
        SettingsSection(
            SettingsCatalog.colors.currentScene,
            caption: L(
                "colors.scene.caption",
                "Everything a palette paints, in one picture: the "
                    + "bar plate and its active item, the focus "
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
                height: 132
            )
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
