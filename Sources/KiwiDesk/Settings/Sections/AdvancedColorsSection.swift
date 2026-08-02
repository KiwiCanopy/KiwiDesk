import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Advanced Colours (#678 Phase 3, turn 12b):
/// every colour KiwiDesk has, on one page, **grouped by where you
/// see it** — borders, drag visuals, Space Bar, App Bar. Not by
/// what it is: a user arrives here having noticed something is
/// the wrong colour, not looking for "highlight colour" in the
/// abstract. That is also why each group leads with the preview
/// its own editor already uses, rather than one composed scene
/// claiming to show all of them at once.
///
/// Rendered from the census: `ColorsRowOrder` gives the display
/// order, `SettingPlacement` the group and tier, and the two bar
/// groups take their block gate from their census container's own
/// `SettingsContainer.gate` — the same containers the Bars page
/// gates from, which is what "a container spans two areas" buys.
///
/// The area's census `minimumMode` is `.nerd`, but no mode toggle
/// ships until Phase 4, so during coexistence it renders
/// unconditionally and sits in the sidebar directly under its
/// Simple twin. That adjacency is the only thing currently saying
/// "this is the deep version of the page above"; when the toggle
/// lands, the row leaves the end of a pair rather than a gap in
/// the middle of the list.
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
