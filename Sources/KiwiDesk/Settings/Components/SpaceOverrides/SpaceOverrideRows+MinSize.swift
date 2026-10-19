import KiwiDeskCore
import SwiftUI

extension SpaceOverrideRows {
    /// The Space's own minimum window size (#2422), beside its
    /// gaps since it too survives a layout switch; inert, greyed
    /// with its reason, while the Space is Monocle.
    @ViewBuilder
    var minSizeRow: some View {
        let reason = gates.inertReason(
            for: .behaviour(.minSizePerSpaceOverride)
        )
        let row = OverrideMinSizeRow(
            value: $model.config.settings.minWindowSizeOverride[space],
            followed: g.minWindowSize(for: minSizeMode, in: nil),
            followedName: minSizeFollowedName
        )
        if let reason {
            let sentence = SpacesGateHelp.sentence(for: reason)
            VStack(alignment: .leading, spacing: 4) {
                row.modifier(GreyOut(active: true, help: sentence))
                Text(sentence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, SettingsMetrics.overrideRowInset)
            }
        } else {
            row
        }
    }

    /// The layout whose floor the Space follows; a Monocle Space
    /// shows the value its next layout would follow, BSP's.
    private var minSizeMode: LayoutMode {
        mode == .monocle ? .bsp : mode
    }

    /// "Follows Grid" where the Space's layout stands apart from
    /// the others, else "Follows Minimum window size".
    private var minSizeFollowedName: String {
        guard let layout = MinWindowSizes.Layout(minSizeMode),
            model.minSizeStandsApart(layout)
        else { return OverrideMinSizeRow.label }
        return minSizeMode.displayName
    }
}
