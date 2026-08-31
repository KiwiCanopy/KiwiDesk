import KiwiDeskCore
import SwiftUI

/// Layout metrics and sizing calculations for `PresetPreviewSheet`
/// (#859, `PresetPreviewSheetTests`).
extension PresetPreviewSheet {
    /// Fixed tile width (`SchematicScale.tile`, `PresetPreviewSheetTests`).
    static let tileWidth = SchematicScale.tile.width ?? 132
    static let gutter: CGFloat = 12
    static let pad: CGFloat = 12
    /// Scroll bar margin reservation (re-review 2026-08-17).
    static let scroller: CGFloat = 16

    /// Derives sheet width required for given column count.
    static func width(forColumns columns: Int) -> CGFloat {
        CGFloat(columns) * tileWidth
            + CGFloat(max(columns - 1, 0)) * gutter
            + 2 * pad
            + scroller
    }

    /// Fixed 4-column layout fitting `SettingsWidthClass.minimum`.
    static let columns = 4

    /// Sheet height boundaries (`PresetPreviewSheetTests`,
    /// code review 2026-08-17).
    static let minHeight: CGFloat = 400
    static let idealHeight: CGFloat = 600
    static let maxHeight: CGFloat = 780
}
