import KiwiDeskCore
import SwiftUI

/// Advanced color settings grouped by WHERE YOU SEE IT — a user
/// arrives having noticed something is the wrong colour
/// (`ColorsRowOrder`, #678). The group previews left in #793: the
/// colours are judged against each other, so the composed scene
/// lives in the detail panel (`AdvancedColorsPanel`), pinned
/// while the rows scroll — the standing rule once an area offers
/// a panel (`docs/design-decisions.md` ▸ two columns).
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
