import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Colours & Animations (#678 Phase 3, turn 12a): the
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
                // The live-colours scene moved to the detail
                // PANEL (`PaletteScenePanel`, #678 redesign spec) —
                // the column beside these rows is where the
                // draft is watched now.
                MotionCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
