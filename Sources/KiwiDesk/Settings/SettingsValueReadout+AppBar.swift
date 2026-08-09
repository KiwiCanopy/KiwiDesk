import CoreGraphics
import KiwiDeskCore

/// Global App Bar rows: every key narrates the one
/// `AppBarStyle` field its census id names. Enum-valued rows
/// reuse the option labels the Bars editor renders
/// (`AppBarOptions`), the auto-sentinel size sliders read
/// "Automatic" at 0 the way the GUI's slider readout does, and
/// a colour shows its stored hex verbatim.
extension SettingsValueReadout {
    static func appBarRows(
        _ key: AppBarKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.appBar(key)
        let o = old.settings.appBarStyle
        let n = new.settings.appBarStyle
        switch key {
        case .appBarEdge:
            return appBarChoiceRow(
                census,
                o.edge,
                n.edge,
                AppBarOptions.edge
            )
        case .appBarAlignment:
            return appBarChoiceRow(
                census,
                o.alignment,
                n.alignment,
                AppBarOptions.alignment
            )
        case .appBarBackground:
            return appBarChoiceRow(
                census,
                o.backgroundStyle,
                n.backgroundStyle,
                AppBarOptions.backgroundStyle
            )
        case .appBarLiquidGlass:
            return appBarOnOffRow(
                census,
                o.liquidGlass,
                n.liquidGlass
            )
        case .appBarBackgroundFit:
            return appBarChoiceRow(
                census,
                o.backgroundFit,
                n.backgroundFit,
                AppBarOptions.backgroundFit
            )
        case .appBarActiveIndicator:
            return appBarChoiceRow(
                census,
                o.activeIndicator,
                n.activeIndicator,
                AppBarOptions.activeIndicator
            )
        case .appBarContent:
            return appBarChoiceRow(
                census,
                o.content,
                n.content,
                AppBarOptions.content
            )
        case .appBarIconSource:
            return appBarChoiceRow(
                census,
                o.iconSource,
                n.iconSource,
                AppBarOptions.iconSource
            )
        case .appBarGroupAdjacentWindows:
            return appBarOnOffRow(
                census,
                o.groupAdjacentWindows,
                n.groupAdjacentWindows
            )
        case .appBarThickness:
            return appBarPointsRow(census, o.thickness, n.thickness)
        case .appBarItemSizeAuto:
            return appBarOnOffRow(
                census,
                o.itemSize == 0,
                n.itemSize == 0
            )
        case .appBarItemSize:
            return appBarAutoPointsRow(
                census,
                o.itemSize,
                n.itemSize
            )
        case .appBarItemGap:
            return appBarPointsRow(census, o.itemGap, n.itemGap)
        case .appBarFontSizeAuto:
            return appBarOnOffRow(
                census,
                o.fontSize == 0,
                n.fontSize == 0
            )
        case .appBarFontSize:
            return appBarAutoPointsRow(
                census,
                o.fontSize,
                n.fontSize
            )
        case .appBarCornerRoundness:
            return appBarRow(
                census,
                percent(Double(o.cornerRoundness) / 100),
                percent(Double(n.cornerRoundness) / 100)
            )
        case .appBarDimFactor:
            return appBarRow(
                census,
                trimmed(o.dimFactor),
                trimmed(n.dimFactor)
            )
        case .appBarFillColor:
            return appBarHexRow(census, o.fillColor, n.fillColor)
        case .appBarHighlightColor:
            return appBarHexRow(
                census,
                o.highlightColor,
                n.highlightColor
            )
        case .appBarItemColor:
            return appBarHexRow(census, o.itemColor, n.itemColor)
        case .appBarActiveItemColor:
            return appBarHexRow(
                census,
                o.activeItemColor,
                n.activeItemColor
            )
        case .appBarHoverFillColor:
            return appBarHexRow(
                census,
                o.hoverFillColor,
                n.hoverFillColor
            )
        case .appBarHoverItemColor:
            return appBarHexRow(
                census,
                o.hoverItemColor,
                n.hoverItemColor
            )
        case .appBarGroupBadgeColor:
            return appBarHexRow(
                census,
                o.groupBadgeColor,
                n.groupBadgeColor
            )
        case .appBarGroupBadgeTextColor:
            return appBarHexRow(
                census,
                o.groupBadgeTextColor,
                n.groupBadgeTextColor
            )
        }
    }
}

// MARK: - App Bar row shapes

extension SettingsValueReadout {
    private static func appBarRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        [
            .change(
                census,
                label: label(for: census),
                old: old,
                new: new
            )
        ]
    }

    private static func appBarOnOffRow(
        _ census: SettingKey,
        _ old: Bool,
        _ new: Bool
    ) -> [SettingsDiffRow] {
        appBarRow(census, onOff(old), onOff(new))
    }

    private static func appBarPointsRow(
        _ census: SettingKey,
        _ old: CGFloat,
        _ new: CGFloat
    ) -> [SettingsDiffRow] {
        appBarRow(census, points(old), points(new))
    }

    /// `0` is the stored auto sentinel on the size sliders —
    /// the shared `autoPoints` reads "Automatic" there.
    private static func appBarAutoPointsRow(
        _ census: SettingKey,
        _ old: CGFloat,
        _ new: CGFloat
    ) -> [SettingsDiffRow] {
        appBarRow(census, autoPoints(old), autoPoints(new))
    }

    private static func appBarChoiceRow<T: Equatable>(
        _ census: SettingKey,
        _ old: T,
        _ new: T,
        _ options: [(T, String)]
    ) -> [SettingsDiffRow] {
        appBarRow(
            census,
            appBarChoice(old, options),
            appBarChoice(new, options)
        )
    }

    /// The label the Bars editor's own option list renders for
    /// this value; the fallback is unreachable while those lists
    /// stay exhaustive (their own docs hold them to it).
    private static func appBarChoice<T: Equatable>(
        _ value: T,
        _ options: [(T, String)]
    ) -> String {
        options.first { $0.0 == value }?.1
            ?? String(describing: value)
    }

    private static func appBarHexRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        appBarRow(census, hexDisplay(old), hexDisplay(new))
    }
}
