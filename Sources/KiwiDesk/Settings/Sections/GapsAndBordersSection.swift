import KiwiDeskCore
import SwiftUI

/// Settings view for Gaps & Borders (#68 §3.2, #678 Phase 3).
struct GapsAndBordersSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            // Mounted card composition pinned by
            // `GapsAndBordersGateWiringTests` (#754).
            VStack(alignment: .leading, spacing: 20) {
                GapsEditor(model: model)
                BordersCard(model: model)
                FocusBorderEditor(model: model)
                DragVisualsEditor(model: model)
                StickyMarkEditor(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
