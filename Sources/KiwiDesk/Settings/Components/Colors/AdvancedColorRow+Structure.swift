import KiwiDeskCore
import SwiftUI

/// The Borders and Drag groups' swatches — the `BordersKey`
/// slice, which owns the ring, the two marks and the drag
/// visuals.
///
/// Two labels are new here: on the Focus-border card each ring
/// colour could be called "Color", because the card was the
/// context. In a Borders group holding three tints, two rows
/// named "Color" name nothing, so they take the wording their
/// VoiceOver labels already carried. The drag rows go the other
/// way — they reuse the `drag.border` / `drag.fill` labels,
/// because the Border/Fill sub-grouping that made "Color"
/// readable does not exist on this page either.
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
            // Deliberately ungated: it also paints the on-window
            // mark, so it always tints something even with the
            // Space Bar off (the census records the same).
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
            // The floating mark's ONLY surface is the Space Bar
            // badge, so this row lives in the Space Bar group and
            // rides that group's container gate — no row gate.
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

    /// One drag column's Border or Fill tint. Both columns edit
    /// the same `DragVisual` shape, so one builder covers four
    /// census rows.
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
