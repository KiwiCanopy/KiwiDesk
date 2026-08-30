import KiwiDeskCore
import SwiftUI

/// Explainer row when both enabled bars share an edge (#293, #374,
/// `TilingSettings.spaceBarSharesEdgeWithAppBar`).
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
