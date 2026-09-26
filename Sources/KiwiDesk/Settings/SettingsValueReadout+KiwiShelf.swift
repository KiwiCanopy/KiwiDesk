import CoreGraphics
import KiwiDeskCore

/// Diff row readout generators for the `KiwiShelf` census keys
/// (#1517), on the Space Bar's row helpers — the same value kinds.
extension SettingsValueReadout {
    static func kiwishelfRows(
        _ key: KiwiShelfKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.kiwishelf(key)
        let o = old.settings.kiwishelf
        let n = new.settings.kiwishelf
        switch key {
        case .edge:
            return spaceBarChoiceRow(
                census,
                o.edge,
                n.edge,
                AppBarOptions.edge
            )
        case .alignment:
            return spaceBarChoiceRow(
                census,
                o.alignment,
                n.alignment,
                AppBarOptions.alignment
            )
        case .order:
            return spaceBarChoiceRow(
                census,
                o.order,
                n.order,
                AppBarOptions.order
            )
        case .minimum:
            return spaceBarRow(
                census,
                percent(Double(o.minimum) / 100),
                percent(Double(n.minimum) / 100)
            )
        case .thickness:
            return spaceBarPointsRow(census, o.thickness, n.thickness)
        case .outerMargin:
            return spaceBarPointsRow(census, o.outerMargin, n.outerMargin)
        case .innerMargin:
            return spaceBarPointsRow(census, o.innerMargin, n.innerMargin)
        case .background:
            return spaceBarChoiceRow(
                census,
                o.backgroundStyle,
                n.backgroundStyle,
                AppBarOptions.backgroundStyle
            )
        case .backgroundFit:
            return spaceBarChoiceRow(
                census,
                o.backgroundFit,
                n.backgroundFit,
                AppBarOptions.backgroundFit
            )
        case .cornerRoundness:
            return spaceBarRow(
                census,
                percent(Double(o.cornerRoundness) / 100),
                percent(Double(n.cornerRoundness) / 100)
            )
        case .highlightWidth:
            return spaceBarPointsRow(
                census,
                o.highlightWidth,
                n.highlightWidth
            )
        case .itemGap:
            return spaceBarPointsRow(census, o.itemGap, n.itemGap)
        case .fontSizeAuto:
            return spaceBarOnOffRow(
                census,
                o.fontSize == 0,
                n.fontSize == 0
            )
        case .fontSize:
            return spaceBarAutoPointsRow(census, o.fontSize, n.fontSize)
        case .liquidGlass:
            return spaceBarOnOffRow(census, o.liquidGlass, n.liquidGlass)
        case .iconSource:
            return spaceBarChoiceRow(
                census,
                o.iconSource,
                n.iconSource,
                AppBarOptions.iconSource
            )
        case .dimFactor:
            return spaceBarRow(
                census,
                trimmed(o.dimFactor),
                trimmed(n.dimFactor)
            )
        case .fillColor, .itemColor, .activeItemColor,
            .highlightColor, .hoverFillColor, .hoverItemColor,
            .groupBadgeColor, .groupBadgeTextColor:
            let path = Self.shelfColor(key)
            return spaceBarHexRow(census, o[keyPath: path], n[keyPath: path])
        }
    }

    /// The stored colour a colour key narrates.
    private static func shelfColor(
        _ key: KiwiShelfKey
    ) -> KeyPath<KiwiShelf, String> {
        switch key {
        case .fillColor: return \.fillColor
        case .itemColor: return \.itemColor
        case .activeItemColor: return \.activeItemColor
        case .highlightColor: return \.highlightColor
        case .hoverFillColor: return \.hoverFillColor
        case .hoverItemColor: return \.hoverItemColor
        case .groupBadgeColor: return \.groupBadgeColor
        default: return \.groupBadgeTextColor
        }
    }
}
