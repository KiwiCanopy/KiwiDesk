import KiwiDeskCore
import SwiftUI

/// The neutral both-bars-share-an-edge explainer (#293/#374),
/// shown under each bar editor's Position row when both
/// *enabled* bars resolve to the same edge
/// (`TilingSettings.spaceBarSharesEdgeWithAppBar`). Never a
/// warning, never a popup.
///
/// Renders the **Space Bar's** edge, never the App Bar's
/// global one: the predicate matches per-layout *resolved*
/// App Bar edges, so the shared edge can legitimately differ
/// from the App Bar's global Position control sitting right
/// above this row (global top, monocle override bottom,
/// Space Bar bottom → the shared edge is bottom).
struct BarSameEdgeRow: View {
    let edge: AppBarEdge

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
    }

    private var text: String {
        let name =
            AppBarOptions.edge.first { $0.0 == edge }?.1 ?? ""
        return L(
            "bars.same_edge",
            "Both bars share the %1$@ edge — Space Bar sits "
                + "at the screen edge, App Bar sits next to "
                + "the windows.",
            name
        )
    }
}
