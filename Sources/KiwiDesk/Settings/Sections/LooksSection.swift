import KiwiDeskCore
import SwiftUI

/// Profile Looks & Animations settings section (#678 Phase 3,
/// #1684): the look shelf directly above the palette shelf, and
/// Colors & glass refining the palette beneath it (#2389).
struct LooksSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SharedLookSection(model: model)
                LooksShelf(model: model)
                PaletteShelf(model: model)
                ColorsAndGlassSection(model: model)
                MotionCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
