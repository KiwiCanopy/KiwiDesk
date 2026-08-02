/// Borders, sticky/floating marks and drag visuals
/// (`BorderStyle`, `StickyStyle`, `FloatingStyle`,
/// `DragGhost`, `DragDropZone`).

enum BordersKey: String, CaseIterable, Hashable {
    case borderEnabled = "settings.borderStyle.enabled"
    case borderFocusedColor = "settings.borderStyle.focusedColor"
    case borderUnfocusedEnabled = "settings.borderStyle.unfocusedEnabled"
    case borderUnfocusedColor = "settings.borderStyle.unfocusedColor"
    case borderWidth = "settings.borderStyle.width"
    case borderCorner = "settings.borderStyle.cornerStyle"
    case borderGlow = "settings.borderStyle.glow"
    case borderGlowSizeAuto = "settings.borderStyle.glowSize (auto)"
    case borderGlowSize = "settings.borderStyle.glowSize"
    case borderDrawOrder = "settings.borderStyle.drawOrder"
    case borderFitGapsExtraSpacing = "(action) border.fit_gaps.extra_spacing"
    case borderFitGaps = "(action) border.fit_gaps"
    case stickyMark = "settings.stickyStyle.mark"
    case stickyColor = "settings.stickyStyle.color"
    case dragCornerRadius = "settings.dragCornerRadius"
    case dragGhostEnabled = "settings.dragGhost.enabled"
    case dragGhostBorder = "settings.dragGhost.border"
    case dragGhostBorderColor = "settings.dragGhost.borderColor"
    case dragGhostBorderWidth = "settings.dragGhost.borderWidth"
    case dragGhostBorderAlignment = "settings.dragGhost.borderAlignment"
    case dragGhostFill = "settings.dragGhost.fill"
    case dragGhostFillColor = "settings.dragGhost.fillColor"
    case dragDropZoneEnabled = "settings.dragDropZone.enabled"
    case dragDropZoneBorder = "settings.dragDropZone.border"
    case dragDropZoneBorderColor = "settings.dragDropZone.borderColor"
    case dragDropZoneBorderWidth = "settings.dragDropZone.borderWidth"
    case dragDropZoneBorderAlignment = "settings.dragDropZone.borderAlignment"
    case dragDropZoneFill = "settings.dragDropZone.fill"
    case dragDropZoneFillColor = "settings.dragDropZone.fillColor"
    case floatingColor = "settings.floatingStyle.color"
}

extension BordersKey {
    var placement: SettingPlacement {
        switch self {
        case .borderEnabled, .borderWidth, .borderFitGapsExtraSpacing:
            return .row(.gapsAndBorders, .focusBorder, .atRest)
        case .borderFocusedColor:
            return .row(.advancedColours, .borders, .atRest)
        case .borderUnfocusedEnabled, .borderCorner, .borderGlow,
            .borderGlowSizeAuto:
            return .row(.gapsAndBorders, .focusBorder, .showMore)
        case .borderUnfocusedColor:
            return .row(
                .advancedColours,
                .borders,
                .atRest,
                gate: .setting(.borders(.borderUnfocusedEnabled))
            )
        case .stickyColor:
            // The mark's color follows the mark being shown
            // (item 10: the mark paints on the window itself).
            return .row(
                .advancedColours,
                .borders,
                .atRest,
                gate: .setting(.borders(.stickyMark))
            )
        case .borderGlowSize:
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .showMore,
                gate: .setting(.borders(.borderGlow))
            )
        case .borderDrawOrder:
            return .luaOnly
        case .borderFitGaps:
            // The whole editor greys off its enable toggle.
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .atRest,
                gate: .setting(.borders(.borderEnabled))
            )
        case .stickyMark:
            // Forced on while the Space Bar is off — the only
            // sticky mark left (StickyMarkEditor).
            return .row(
                .gapsAndBorders,
                .stickyWindows,
                .showMore,
                gate: .setting(.spaceBar(.spaceBarEnabled))
            )
        case .dragCornerRadius, .dragGhostBorder, .dragGhostFill,
            .dragDropZoneBorder, .dragDropZoneBorderWidth,
            .dragDropZoneBorderAlignment, .dragDropZoneFill:
            return .row(.gapsAndBorders, .dragAndDrop, .showMore)
        case .dragGhostEnabled, .dragDropZoneEnabled:
            return .row(.gapsAndBorders, .dragAndDrop, .atRest)
        case .dragGhostBorderColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .setting(.borders(.dragGhostBorder))
            )
        case .dragGhostFillColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .setting(.borders(.dragGhostFill))
            )
        case .dragGhostBorderWidth, .dragGhostBorderAlignment:
            return .row(
                .gapsAndBorders,
                .dragAndDrop,
                .showMore,
                gate: .setting(.borders(.dragGhostBorder))
            )
        case .dragDropZoneBorderColor, .dragDropZoneFillColor:
            return .row(.advancedColours, .dragAndDrop, .atRest)
        case .floatingColor:
            // Drawn only in the Space Bar (owner ruling
            // 2026-08-02; the gate item 10 keeps).
            return .row(
                .advancedColours,
                .spaceBar,
                .atRest,
                gate: .setting(.spaceBar(.spaceBarEnabled))
            )
        }
    }
}

extension BordersKey {
    var text: SettingRowText {
        switch self {
        case .borderEnabled:
            return .text("border.enabled")
        case .borderFocusedColor:
            return .text("border.focused_color")
        case .borderUnfocusedEnabled:
            return .text("border.unfocused_enabled")
        case .borderUnfocusedColor:
            return .text("border.unfocused_color")
        case .borderWidth:
            return .text("border.width")
        case .borderCorner:
            return .text("border.corner_style")
        case .borderGlow:
            return .text("border.glow")
        case .borderGlowSizeAuto:
            return .text("border.glow_size.auto")
        case .borderGlowSize:
            return .text("border.glow_size")
        case .borderDrawOrder:
            return .none
        case .borderFitGapsExtraSpacing:
            return .text("border.fit_gaps.extra_spacing")
        case .borderFitGaps:
            return .text("border.fit_gaps.action")
        case .stickyMark:
            return .text("sticky.mark", help: "sticky.mark.help")
        case .stickyColor:
            return .text("sticky.color")
        case .dragCornerRadius:
            return .text("drag.corner_radius")
        case .dragGhostEnabled, .dragDropZoneEnabled:
            return .text("drag.enabled")
        case .dragGhostBorder, .dragDropZoneBorder:
            return .text("drag.border")
        case .dragGhostBorderColor, .dragDropZoneBorderColor:
            return .text("drag.border_color")
        case .dragGhostBorderWidth, .dragDropZoneBorderWidth:
            return .text("drag.border_width")
        case .dragGhostBorderAlignment, .dragDropZoneBorderAlignment:
            return .text("drag.border_alignment")
        case .dragGhostFill, .dragDropZoneFill:
            return .text("drag.fill")
        case .dragGhostFillColor, .dragDropZoneFillColor:
            return .text("drag.fill_color")
        case .floatingColor:
            return .text("floating.color")
        }
    }
}
