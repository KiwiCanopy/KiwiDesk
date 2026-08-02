import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Gaps & Borders (#68 §3.2, renamed in #678
/// Phase 3): the STRUCTURE of what KiwiDesk draws around windows
/// — spacing, the drag visuals' shape, the focus ring's width and
/// glow, the sticky mark's presence. Every colour on it moved to
/// the two Colours areas.
///
/// The rename is the point of the change, not a side effect. The
/// page was called Appearance, which is the most colour-sounding
/// word in the app; after the split it owns no colour, so leaving
/// the name would have made it the wrong answer to "where do I
/// change the ring colour" — and the sidebar search indexes
/// destination titles, so it would have kept giving that answer.
/// The new name is the one the census already gives this area
/// (`SettingsArea.gapsAndBorders`), so the interim sidebar
/// pre-teaches the Home card that eventually replaces it rather
/// than teaching a name that dies.
struct GapsAndBordersSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GapsEditor(model: model)
                DragVisualsEditor(model: model)
                FocusBorderEditor(model: model)
                StickyMarkEditor(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
