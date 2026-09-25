import KiwiDeskCore
import SwiftUI

/// Profile Bars settings section: the KiwiShelf card, then the
/// Space Bar and App Bar cards (#293, #678, #1517). No colours
/// here: a colour renders in ONE area — Advanced Colours — which
/// `SettingsColorSurfaceTests` pins.
struct BarsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                KiwiShelfCard(model: model)
                SpaceBarCard(model: model)
                AppBarCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
