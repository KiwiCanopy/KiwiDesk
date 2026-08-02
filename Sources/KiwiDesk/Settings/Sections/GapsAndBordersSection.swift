import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Gaps & Borders (#68 §3.2, renamed in #678
/// Phase 3): the STRUCTURE of what KiwiDesk draws around windows
/// — spacing, the drag visuals' shape, the focus ring's width and
/// glow, the sticky mark's presence. Every colour on it moved to
/// the two Colours areas.
///
/// The name is the census's own for this area
/// (`SettingsArea.gapsAndBorders`), so the interim sidebar
/// teaches the name that survives into the Home card rather than
/// one that dies with the sidebar. Why the rename was owed at
/// all — a destination title is a search key, so a page must not
/// keep a name for content it no longer has — is argued in
/// `docs/design-decisions.md` under "Colour is its own
/// destination".
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
