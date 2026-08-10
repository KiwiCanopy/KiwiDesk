import KiwiDeskCore
import SwiftUI

/// The Gaps & Borders panel content (#678 redesign spec): the two
/// pictures this area always had, recycled whole — the gap
/// miniature with its legend, and the focus-ring pair — now
/// stacked in the panel column instead of leading their cards.
/// Deliberately NOT a new fused desktop scene: each picture is
/// an existing renderer with its own guard surface, and the
/// redesign rule is recycle, never rebuild beside one.
struct GapsBordersPanelPreview: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GapsDiagram(
                outer: model.config.settings.gapsGlobal.outer,
                inner: model.config.settings.gapsGlobal.inner
            )
            FocusBorderPreview(
                style: model.config.settings.borderStyle
            )
            DragVisualPreview(
                visual: model.config.settings.dragGhost,
                cornerRadius: model.config.settings
                    .dragCornerRadius
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
