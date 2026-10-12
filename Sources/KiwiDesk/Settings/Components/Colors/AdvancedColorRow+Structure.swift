import KiwiDeskCore
import SwiftUI

/// Advanced color swatches for borders and drag visuals.
extension AdvancedColorRow {
    @ViewBuilder func structureRow(_ key: BordersKey) -> some View {
        switch key {
        case .borderFocusedColor:
            HexColorField(
                label: L("border.title", "Focus border"),
                a11yLabel: L(
                    "border.focused_color.a11y",
                    "Focused window border color"
                ),
                hex: settings.borderStyle.focusedColor
            )
        case .borderUnfocusedColor:
            HexColorField(
                label: L(
                    "border.color.unfocused",
                    "Unfocused windows"
                ),
                a11yLabel: L(
                    "border.unfocused_color.a11y",
                    "Unfocused window border color"
                ),
                hex: settings.borderStyle.unfocusedColor
            )
        case .stickyColor:
            HexColorField(
                label: L("sticky.color", "Sticky"),
                a11yLabel: L(
                    "sticky.color.a11y",
                    "Sticky window mark color"
                ),
                automatic: true,
                hex: settings.stickyStyle.color
            )
        case .floatingColor:
            HexColorField(
                label: L("floating.color", "Floating"),
                a11yLabel: L(
                    "floating.color.a11y",
                    "Floating window mark color"
                ),
                automatic: true,
                hex: settings.floatingStyle.color
            )
        case .dragGhostBorderColor:
            dragRow(ghost: true, fill: false)
        case .dragGhostFillColor:
            dragRow(ghost: true, fill: true)
        case .dragDropZoneBorderColor:
            dragRow(ghost: false, fill: false)
        case .dragDropZoneFillColor:
            dragRow(ghost: false, fill: true)
        default:
            let _ = assertionFailure(
                "non-colour Borders key in Advanced Colours: "
                    + key.rawValue
            )
            EmptyView()
        }
    }

    /// Swatch row for one drag tint, labelled by its visual
    /// since the two visuals sit in different groups (#1857).
    @ViewBuilder private func dragRow(
        ghost: Bool,
        fill: Bool
    ) -> some View {
        let visual = ghost ? settings.dragGhost : settings.dragDropZone
        HexColorField(
            label: dragLabel(ghost: ghost, fill: fill),
            hex: fill ? visual.fillColor : visual.borderColor
        )
    }

    private func dragLabel(ghost: Bool, fill: Bool) -> String {
        switch (ghost, fill) {
        case (true, false):
            return L("colors.ghost_border", "Ghost border")
        case (true, true):
            return L("colors.ghost_fill", "Ghost fill")
        case (false, false):
            return L("colors.drop_zone_border", "Drop zone border")
        case (false, true):
            return L("colors.drop_zone_fill", "Drop zone fill")
        }
    }
}
