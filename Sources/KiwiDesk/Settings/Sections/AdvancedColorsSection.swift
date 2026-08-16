import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Advanced Colours (#678 Phase 3, turn 12b):
/// every colour KiwiDesk has, on one page, **grouped by where you
/// see it** — borders, drag visuals, Space Bar, App Bar. Not by
/// what it is: a user arrives here having noticed something is
/// the wrong colour, not looking for "highlight colour" in the
/// abstract.
///
/// **The group previews left in #793, and the ruling that put
/// them here is overturned.** This comment used to end "that is
/// also why each group leads with the preview its own editor
/// already uses, rather than one composed scene claiming to show
/// all of them at once". Grouping by where you see it is still
/// right — it decides the ROWS. What it does not settle is
/// whether the picture should be per-group, and four separate
/// previews cannot answer the question this page exists to ask:
/// the accent ladders, the two rings, the state marks and the
/// drag pair are judged against each other, so a reader had to
/// save and look at the desktop to see whether their set worked.
/// The composed scene now lives in the detail panel
/// (`AdvancedColorsPanel`), where it is pinned while the rows
/// scroll — which is also the standing rule once an area offers
/// a panel (`docs/design-decisions.md` ▸ two columns).
///
/// Rendered from the census: `ColorsRowOrder` gives the display
/// order, `SettingPlacement` the group and tier, and the two bar
/// groups take their block gate from their census container's own
/// `SettingsContainer.gate` — the same containers the Bars page
/// gates from, which is what "a container spans two areas" buys.
///
/// The area's census `minimumMode` is `.powerUser`, but no mode toggle
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
