import KiwiDeskCore
import SwiftUI

/// Layout metrics and sizing calculations for `PresetPreviewSheet`
/// (#859, `PresetPreviewSheetTests`).
extension PresetPreviewSheet {
    /// Fixed tile width (`SchematicScale.tile`, `PresetPreviewSheetTests`).
    static let tileWidth = SchematicScale.tile.width ?? 132
    static let gutter: CGFloat = 12
    static let pad: CGFloat = 12
    /// Room for a LEGACY scroll bar ("Show scroll bars: Always"),
    /// which insets a `ScrollView`'s content instead of overlaying
    /// it — without the reservation it re-wrapped or clipped the
    /// fourth column (re-review 2026-08-17).
    static let scroller: CGFloat = 16

    /// Derives sheet width required for given column count.
    static func width(forColumns columns: Int) -> CGFloat {
        CGFloat(columns) * tileWidth
            + CGFloat(max(columns - 1, 0)) * gutter
            + 2 * pad
            + scroller
    }

    /// Four: what the arithmetic allows at the narrowest window —
    /// `SettingsWidthClass.minimum` is 720 and five columns need
    /// 732 — and every shipped preset puts at most four Spaces on
    /// one screen, so each screen group is exactly one row.
    static let columns = 4

    /// Sheet height bounds. `minHeight` is a RELATION, not a
    /// taste: it must stay under the shell's minimum content
    /// height, and `PresetPreviewSheetTests` asserts it against
    /// `SettingsWidthClass.minimumHeight` rather than 400. The max
    /// is a growth stop, not a promise about the window (code
    /// review 2026-08-17).
    static let minHeight: CGFloat = 400
    static let idealHeight: CGFloat = 600
    static let maxHeight: CGFloat = 780
}
