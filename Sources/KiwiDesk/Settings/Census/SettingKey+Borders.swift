/// Borders, sticky/floating marks and drag visuals census slice (#754).

enum BordersKey: String, CaseIterable, Hashable {
    case borderEnabled = "settings.borderStyle.enabled"
    case borderFocusedColor = "settings.borderStyle.focusedColor"
    case borderUnfocusedEnabled = "settings.borderStyle.unfocusedEnabled"
    case borderUnfocusedColor = "settings.borderStyle.unfocusedColor"
    case borderWidth = "settings.borderStyle.width"
    case borderCorner = "settings.borderStyle.cornerStyle"
    case borderWidthMaster = "settings.borderStyle.width (master)"
    case borderCornerMaster =
        "settings.borderStyle.cornerStyle (master)"
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
        case .borderEnabled:
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .atRest,
                exemptFromContainerGate: true
            )
        case .borderWidthMaster, .borderCornerMaster:
            return .row(.gapsAndBorders, .borders, .atRest)
        case .borderFitGapsExtraSpacing:
            return .row(.gapsAndBorders, .focusBorder, .showMore)
        case .borderFocusedColor:
            return .row(
                .advancedColours,
                .borders,
                .atRest,
                gate: .setting(.borders(.borderEnabled))
            )
        case .borderUnfocusedEnabled, .borderGlow,
            .borderGlowSizeAuto:
            return .row(.gapsAndBorders, .focusBorder, .showMore)
        case .borderUnfocusedColor:
            return .row(
                .advancedColours,
                .borders,
                .atRest,
                gate: .anyOf([
                    .borders(.borderEnabled),
                    .borders(.borderUnfocusedEnabled),
                ])
            )
        case .stickyColor:
            return .row(.advancedColours, .borders, .atRest)
        case .borderGlowSize:
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .showMore,
                gate: .anyOf([
                    .borders(.borderGlow),
                    .borders(.borderGlowSizeAuto),
                ])
            )
        case .borderDrawOrder:
            return .luaOnly
        case .borderFitGaps:
            return .row(.gapsAndBorders, .focusBorder, .atRest)
        case .stickyMark:
            // Ungated (StickyMarkUngatedTests).
            return .row(
                .gapsAndBorders,
                .stickyWindows,
                .showMore
            )
        case .dragGhostEnabled, .dragDropZoneEnabled:
            return .row(.gapsAndBorders, .dragAndDrop, .atRest)
        case .dragGhostBorder, .dragGhostFill:
            return .row(
                .gapsAndBorders,
                .dragAndDrop,
                .showMore,
                gate: .setting(.borders(.dragGhostEnabled))
            )
        case .dragDropZoneBorder, .dragDropZoneFill:
            return .row(
                .gapsAndBorders,
                .dragAndDrop,
                .showMore,
                gate: .setting(.borders(.dragDropZoneEnabled))
            )
        case .dragGhostBorderColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .anyOf([
                    .borders(.dragGhostEnabled),
                    .borders(.dragGhostBorder),
                ])
            )
        case .dragGhostFillColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .anyOf([
                    .borders(.dragGhostEnabled),
                    .borders(.dragGhostFill),
                ])
            )
        case .borderWidth, .borderCorner,
            .dragGhostBorderWidth,
            .dragDropZoneBorderWidth,
            .dragCornerRadius,
            .dragGhostBorderAlignment,
            .dragDropZoneBorderAlignment:
            return .luaOnly
        case .dragDropZoneBorderColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .anyOf([
                    .borders(.dragDropZoneEnabled),
                    .borders(.dragDropZoneBorder),
                ])
            )
        case .dragDropZoneFillColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .anyOf([
                    .borders(.dragDropZoneEnabled),
                    .borders(.dragDropZoneFill),
                ])
            )
        case .floatingColor:
            return .row(.advancedColours, .spaceBar, .showMore)
        }
    }
}
