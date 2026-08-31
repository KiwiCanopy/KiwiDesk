import KiwiDeskCore
import SwiftUI

/// Profile Bars settings section with Space Bar and App Bar cards
/// (#293, #678).
struct BarsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SpaceBarCard(model: model)
                AppBarCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
