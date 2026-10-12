import KiwiDeskCore
import SwiftUI

/// Advanced color settings: the two role groups first, then the
/// rest by surface (`ColorsRowOrder`, #678, #793, #1857).
struct AdvancedColorsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SharedLookPointer(model: model)
                RoleColorCards(model: model)
                KiwiShelfColorCard(model: model)
                WindowMarksColorCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
