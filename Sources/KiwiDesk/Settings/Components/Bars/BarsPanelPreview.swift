import KiwiDeskCore
import SwiftUI

/// The Bars panel content (digest §1.1, turn 7a's "both bars
/// at their real thickness against a scaled desktop"): the two
/// existing strips, recycled whole into the panel column
/// instead of leading their cards. The Space Bar strip already
/// knows about edge coexistence with the App Bar, so the pair
/// here is the same pair the cards drew — one renderer each,
/// no second drawing.
struct BarsPanelPreview: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SpaceBarPreviewStrip(
                style: model.config.settings.spaceBarStyle,
                appBar: model.config.settings.appBarStyle,
                sameEdge: model.config.settings
                    .spaceBarSharesEdgeWithAppBar
            )
            AppBarPreviewStrip(
                style: model.config.settings.appBarStyle
            )
            Text(
                L(
                    "panel.caption.draft",
                    "Shows your draft, not the saved profile."
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
        }
    }
}
