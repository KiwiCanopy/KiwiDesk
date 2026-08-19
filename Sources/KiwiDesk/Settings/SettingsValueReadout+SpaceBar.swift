import CoreGraphics
import KiwiDeskCore

/// Space Bar rows: every key narrates the one `SpaceBarStyle`
/// field its census id names. Enum-valued rows reuse the option
/// labels the Bars editor renders (`AppBarOptions` — the Space
/// Bar's own pickers already read those lists), the
/// auto-sentinel size sliders read "Automatic" at 0 the way the
/// GUI's slider readout does, and a colour shows its stored hex
/// verbatim. The copy-appearance action stores nothing, so it
/// draws no row.
extension SettingsValueReadout {
    static func spaceBarRows(
        _ key: SpaceBarKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.spaceBar(key)
        let o = old.settings.spaceBarStyle
        let n = new.settings.spaceBarStyle
        switch key {
        case .spaceBarEnabled:
            return spaceBarOnOffRow(census, o.enabled, n.enabled)
        case .spaceBarEdge:
            return spaceBarChoiceRow(
                census,
                o.edge,
                n.edge,
                AppBarOptions.edge
            )
        case .spaceBarAlignment:
            return spaceBarChoiceRow(
                census,
                o.alignment,
                n.alignment,
                AppBarOptions.alignment
            )
        case .spaceBarBackground:
            return spaceBarChoiceRow(
                census,
                o.backgroundStyle,
                n.backgroundStyle,
                AppBarOptions.backgroundStyle
            )
        case .spaceBarLiquidGlass:
            return spaceBarOnOffRow(census, o.liquidGlass, n.liquidGlass)
        case .spaceBarBackgroundFit:
            return spaceBarChoiceRow(
                census,
                o.backgroundFit,
                n.backgroundFit,
                AppBarOptions.backgroundFit
            )
        case .spaceBarActiveIndicator:
            return spaceBarChoiceRow(
                census,
                o.activeIndicator,
                n.activeIndicator,
                AppBarOptions.activeIndicator
            )
        case .spaceBarIconSource:
            return spaceBarChoiceRow(
                census,
                o.iconSource,
                n.iconSource,
                AppBarOptions.iconSource
            )
        case .spaceBarHideEmpty:
            return spaceBarOnOffRow(census, o.hideEmpty, n.hideEmpty)
        case .spaceBarShowFrontApp:
            return spaceBarOnOffRow(
                census,
                o.showFrontApp,
                n.showFrontApp
            )
        case .spaceBarSpringDelay:
            return spaceBarRow(
                census,
                spaceBarSeconds(o.springDelay),
                spaceBarSeconds(n.springDelay)
            )
        case .spaceBarThickness:
            return spaceBarPointsRow(census, o.thickness, n.thickness)
        case .spaceBarItemSizeAuto:
            return spaceBarOnOffRow(
                census,
                o.itemSize == 0,
                n.itemSize == 0
            )
        case .spaceBarItemSize:
            return spaceBarAutoPointsRow(census, o.itemSize, n.itemSize)
        case .spaceBarItemGap:
            return spaceBarPointsRow(census, o.itemGap, n.itemGap)
        case .spaceBarFontSizeAuto:
            return spaceBarOnOffRow(
                census,
                o.fontSize == 0,
                n.fontSize == 0
            )
        case .spaceBarFontSize:
            return spaceBarAutoPointsRow(census, o.fontSize, n.fontSize)
        case .spaceBarGlyphCap:
            return spaceBarRow(
                census,
                trimmed(Double(o.glyphCap)),
                trimmed(Double(n.glyphCap))
            )
        case .spaceBarTitleCap:
            return spaceBarRow(
                census,
                trimmed(Double(o.titleCap)),
                trimmed(Double(n.titleCap))
            )
        case .spaceBarCornerRoundness:
            return spaceBarRow(
                census,
                percent(Double(o.cornerRoundness) / 100),
                percent(Double(n.cornerRoundness) / 100)
            )
        case .spaceBarDimFactor:
            return spaceBarRow(
                census,
                trimmed(o.dimFactor),
                trimmed(n.dimFactor)
            )
        case .spaceBarActiveDimFactor:
            return spaceBarRow(
                census,
                trimmed(o.activeDimFactor),
                trimmed(n.activeDimFactor)
            )
        case .spaceBarStickyBadge:
            return spaceBarOnOffRow(census, o.stickyBadge, n.stickyBadge)
        case .spaceBarItemColor:
            return spaceBarHexRow(census, o.itemColor, n.itemColor)
        case .spaceBarActiveItemColor:
            return spaceBarHexRow(census, o.activeItemColor, n.activeItemColor)
        case .spaceBarFocusedItemColor:
            return spaceBarHexRow(
                census,
                o.focusedItemColor,
                n.focusedItemColor
            )
        case .spaceBarFillColor:
            return spaceBarHexRow(census, o.fillColor, n.fillColor)
        case .spaceBarHighlightColor:
            return spaceBarHexRow(census, o.highlightColor, n.highlightColor)
        case .spaceBarHoverFillColor:
            return spaceBarHexRow(census, o.hoverFillColor, n.hoverFillColor)
        case .spaceBarHoverItemColor:
            return spaceBarHexRow(census, o.hoverItemColor, n.hoverItemColor)
        case .spaceBarGroupBadgeColor:
            return spaceBarHexRow(census, o.groupBadgeColor, n.groupBadgeColor)
        case .spaceBarGroupBadgeTextColor:
            return spaceBarHexRow(
                census,
                o.groupBadgeTextColor,
                n.groupBadgeTextColor
            )
        case .copyAppearance:
            // An action, not stored state — nothing to diff.
            return []
        }
    }
}

// MARK: - Space Bar row shapes

extension SettingsValueReadout {
    private static func spaceBarRow(
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

    private static func spaceBarOnOffRow(
        _ census: SettingKey,
        _ old: Bool,
        _ new: Bool
    ) -> [SettingsDiffRow] {
        spaceBarRow(census, onOff(old), onOff(new))
    }

    private static func spaceBarPointsRow(
        _ census: SettingKey,
        _ old: CGFloat,
        _ new: CGFloat
    ) -> [SettingsDiffRow] {
        spaceBarRow(census, points(old), points(new))
    }

    /// `0` is the stored auto sentinel on the size sliders —
    /// the shared `autoPoints` reads "Automatic" there.
    private static func spaceBarAutoPointsRow(
        _ census: SettingKey,
        _ old: CGFloat,
        _ new: CGFloat
    ) -> [SettingsDiffRow] {
        spaceBarRow(census, autoPoints(old), autoPoints(new))
    }

    private static func spaceBarChoiceRow<T: Equatable>(
        _ census: SettingKey,
        _ old: T,
        _ new: T,
        _ options: [(T, String)]
    ) -> [SettingsDiffRow] {
        spaceBarRow(
            census,
            spaceBarChoice(old, options),
            spaceBarChoice(new, options)
        )
    }

    /// The label the Bars editor's own option list renders for
    /// this value; the fallback is unreachable while those lists
    /// stay exhaustive (their own docs hold them to it).
    private static func spaceBarChoice<T: Equatable>(
        _ value: T,
        _ options: [(T, String)]
    ) -> String {
        options.first { $0.0 == value }?.1
            ?? String(describing: value)
    }

    /// "1.5 s" — the spring-delay readout unit (`SecondsRow`
    /// prints seconds at one decimal, so this matches it).
    private static func spaceBarSeconds(_ ms: Int) -> String {
        L(
            "diff.value.seconds",
            "%1$@ s",
            String(format: "%.1f", Double(ms) / 1000)
        )
    }

    private static func spaceBarHexRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        spaceBarRow(census, hexDisplay(old), hexDisplay(new))
    }
}
