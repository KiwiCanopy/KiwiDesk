import KiwiDeskCore
import SwiftUI

/// Profile Colours & Animations settings section (#678 Phase 3).
struct ColorsMotionSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaletteShelf(model: model)
                MotionCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
