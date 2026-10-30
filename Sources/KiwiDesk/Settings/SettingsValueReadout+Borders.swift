import CoreGraphics
import KiwiDeskCore

/// Borders, marks, and drag visual settings diff row generators (#754).
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
        case .floatingMark:
            return bordersOnOffRow(
                census,
                old.settings.floatingStyle.mark,
                new.settings.floatingStyle.mark
            )
        case .stickyDesktopReach:
            return bordersOnOffRow(
                census,
                old.settings.stickyStyle.desktopReach,
                new.settings.stickyStyle.desktopReach
            )
        case .stickyColor:
            return bordersAutoHexRow(
                census,
                old.settings.stickyStyle.color,
                new.settings.stickyStyle.color
            )
        case .dragGhostEnabled:
            return bordersOnOffRow(census, og.enabled, ng.enabled)
        case .dragDropZoneEnabled:
            return bordersOnOffRow(census, od.enabled, nd.enabled)
        case .floatingColor:
            return bordersAutoHexRow(
                census,
                old.settings.floatingStyle.color,
                new.settings.floatingStyle.color
            )
        case .pocketColor:
            return bordersAutoHexRow(
                census,
                old.settings.pocketStyle.color,
                new.settings.pocketStyle.color
            )
        }
    }
}
