import KiwiDeskCore
import SwiftUI

/// Advanced color settings grouped by visual surface
/// (`ColorsRowOrder`, #678, #793).
struct AdvancedColorsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BorderColorCard(model: model)
                DragColorCard(model: model)
                SpaceBarColorCard(model: model)
                AppBarColorCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
