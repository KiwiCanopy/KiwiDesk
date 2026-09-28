import KiwiDeskCore
import SwiftUI

/// Profile Looks & Animations settings section (#678 Phase 3,
/// #1684): the look shelf directly above the palette shelf.
struct LooksSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LooksShelf(model: model)
                PaletteShelf(model: model)
                GlassCard(model: model)
                MotionCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
