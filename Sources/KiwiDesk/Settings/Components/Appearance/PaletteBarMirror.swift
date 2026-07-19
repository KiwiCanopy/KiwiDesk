import KiwiDeskCore
import SwiftUI

/// The bars' palette mirror (ui-designer 2026-07-19): every
/// other surface a palette paints self-previews on this page
/// (gaps, drag visuals, focus border), but the bar editors
/// moved to their own tab in #229 — so a palette click looked
/// dead here even though the bars took most of the paint. The
/// established preview strips close that gap: they render
/// straight off the staged styles the shelf just painted and
/// animate on change. Live-apply stays out (#123) — this is
/// feedback, not a link.
struct PaletteBarMirror: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AppBarPreviewStrip(
                style: model.config.settings.appBarStyle
            )
            SpaceBarPreviewStrip(
                style: model.config.settings.spaceBarStyle,
                appBar: model.config.settings.appBarStyle,
                sameEdge: model.config.settings
                    .spaceBarSharesEdgeWithAppBar
            )
        }
    }
}
