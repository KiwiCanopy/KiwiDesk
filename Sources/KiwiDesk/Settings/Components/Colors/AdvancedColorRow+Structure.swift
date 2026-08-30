import KiwiDeskCore
import SwiftUI

/// Advanced color swatches for borders and drag visuals.
extension AdvancedColorRow {
    @ViewBuilder func structureRow(_ key: BordersKey) -> some View {
        switch key {
        case .borderFocusedColor:
            HexColorField(
                label: L("border.color.focused", "Focused window"),
                a11yLabel: L(
                    "border.focused_color.a11y",
                    "Focused window border color"
                ),
                hex: settings.borderStyle.focusedColor
            )
            .modifier(
                gated(!gates.borderOn, AdvancedColorsHelp.borderOff)
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
            .modifier(gated(unfocusedInert, unfocusedHelp))
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

    /// Swatch row for drag visuals (ghost and drop zone).
    @ViewBuilder private func dragRow(
        ghost: Bool,
        fill: Bool
    ) -> some View {
        let visual = ghost ? settings.dragGhost : settings.dragDropZone
        let live = gates.dragVisual(ghost)
        let inert =
            !live.enabled || (fill ? !live.fill : !live.border)
        let help =
            !live.enabled
            ? AdvancedColorsHelp.dragOff
            : (fill
                ? AdvancedColorsHelp.dragFillOff
                : AdvancedColorsHelp.dragBorderOff)
        HexColorField(
            label: fill
                ? L("drag.fill", "Fill") : L("drag.border", "Border"),
            a11yLabel: fill
                ? L("drag.fill_color.a11y", "Fill color")
                : L("drag.border_color.a11y", "Border color"),
            labelWidth: SettingsMetrics.dragColumnLabelColumn,
            hex: fill ? visual.fillColor : visual.borderColor
        )
        .modifier(gated(inert, help))
    }

    private var unfocusedInert: Bool {
        !gates.borderOn || !gates.unfocusedOn
    }

    private var unfocusedHelp: String {
        gates.borderOn
            ? AdvancedColorsHelp.unfocusedOff
            : AdvancedColorsHelp.borderOff
    }
}
