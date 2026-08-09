import CoreGraphics
import KiwiDeskCore

/// Borders, marks and drag-visual rows. The two master rows
/// narrate the shared value the #754 card shows — reading
/// "mixed" where the strokes disagree, resolved through
/// `GapsBordersGates.agreedCornerStyle`, the one copy of that
/// comparison — while the master-written leaves narrate their
/// own stored values for a Lua edit that split them. The two
/// fit-gaps rows are actions and store nothing, so they draw
/// no row. Colours show their stored hex; the two mark tints'
/// empty sentinel reads "Automatic" the way the colour well's
/// own field prints it. The value formatters and the row shape
/// live in `SettingsValueReadout+BordersValues.swift`.
extension SettingsValueReadout {
    static func bordersRows(
        _ key: BordersKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.borders(key)
        let ob = old.settings.borderStyle
        let nb = new.settings.borderStyle
        let og = old.settings.dragGhost
        let ng = new.settings.dragGhost
        let od = old.settings.dragDropZone
        let nd = new.settings.dragDropZone
        switch key {
        case .borderEnabled:
            return bordersOnOffRow(census, ob.enabled, nb.enabled)
        case .borderFocusedColor:
            return bordersHexRow(
                census,
                ob.focusedColor,
                nb.focusedColor
            )
        case .borderUnfocusedEnabled:
            return bordersOnOffRow(
                census,
                ob.unfocusedEnabled,
                nb.unfocusedEnabled
            )
        case .borderUnfocusedColor:
            return bordersHexRow(
                census,
                ob.unfocusedColor,
                nb.unfocusedColor
            )
        case .borderWidth:
            return bordersPointsRow(census, ob.width, nb.width)
        case .borderCorner:
            return bordersRow(
                census,
                bordersCornerLabel(ob.cornerStyle),
                bordersCornerLabel(nb.cornerStyle)
            )
        case .borderWidthMaster:
            return bordersRow(
                census,
                bordersUnifiedWidth(old.settings),
                bordersUnifiedWidth(new.settings)
            )
        case .borderCornerMaster:
            return bordersRow(
                census,
                bordersAgreedCorner(old.settings),
                bordersAgreedCorner(new.settings)
            )
        case .borderGlow:
            return bordersOnOffRow(census, ob.glow, nb.glow)
        case .borderGlowSizeAuto:
            return bordersOnOffRow(
                census,
                ob.glowSize == 0,
                nb.glowSize == 0
            )
        case .borderGlowSize:
            return bordersRow(
                census,
                autoPoints(ob.glowSize),
                autoPoints(nb.glowSize)
            )
        case .borderDrawOrder:
            return bordersRow(
                census,
                bordersDrawOrderLabel(ob.drawOrder),
                bordersDrawOrderLabel(nb.drawOrder)
            )
        case .borderFitGapsExtraSpacing, .borderFitGaps:
            // The one-shot action and its parameter — neither
            // is stored state, so there is nothing to diff.
            return []
        case .stickyMark:
            return bordersOnOffRow(
                census,
                old.settings.stickyStyle.mark,
                new.settings.stickyStyle.mark
            )
        case .stickyColor:
            return bordersAutoHexRow(
                census,
                old.settings.stickyStyle.color,
                new.settings.stickyStyle.color
            )
        case .dragCornerRadius:
            return bordersPointsRow(
                census,
                old.settings.dragCornerRadius,
                new.settings.dragCornerRadius
            )
        case .dragGhostEnabled:
            return bordersOnOffRow(census, og.enabled, ng.enabled)
        case .dragGhostBorder:
            return bordersOnOffRow(census, og.border, ng.border)
        case .dragGhostBorderColor:
            return bordersHexRow(
                census,
                og.borderColor,
                ng.borderColor
            )
        case .dragGhostBorderWidth:
            return bordersPointsRow(
                census,
                og.borderWidth,
                ng.borderWidth
            )
        case .dragGhostBorderAlignment:
            return bordersRow(
                census,
                bordersAlignmentLabel(og.borderAlignment),
                bordersAlignmentLabel(ng.borderAlignment)
            )
        case .dragGhostFill:
            return bordersOnOffRow(census, og.fill, ng.fill)
        case .dragGhostFillColor:
            return bordersHexRow(census, og.fillColor, ng.fillColor)
        case .dragDropZoneEnabled:
            return bordersOnOffRow(census, od.enabled, nd.enabled)
        case .dragDropZoneBorder:
            return bordersOnOffRow(census, od.border, nd.border)
        case .dragDropZoneBorderColor:
            return bordersHexRow(
                census,
                od.borderColor,
                nd.borderColor
            )
        case .dragDropZoneBorderWidth:
            return bordersPointsRow(
                census,
                od.borderWidth,
                nd.borderWidth
            )
        case .dragDropZoneBorderAlignment:
            return bordersRow(
                census,
                bordersAlignmentLabel(od.borderAlignment),
                bordersAlignmentLabel(nd.borderAlignment)
            )
        case .dragDropZoneFill:
            return bordersOnOffRow(census, od.fill, nd.fill)
        case .dragDropZoneFillColor:
            return bordersHexRow(census, od.fillColor, nd.fillColor)
        case .floatingColor:
            return bordersAutoHexRow(
                census,
                old.settings.floatingStyle.color,
                new.settings.floatingStyle.color
            )
        }
    }
}
