import CoreGraphics
import Foundation
import KiwiDeskCore

/// Diff row readout generators for SpaceBarStyle census keys.
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
        case .spaceBarActiveIndicator:
            return spaceBarChoiceRow(
                census,
                o.activeIndicator,
                n.activeIndicator,
                AppBarOptions.activeIndicator
            )
        case .spaceBarGroupAdjacent:
            return spaceBarOnOffRow(
                census,
                o.groupAdjacentWindows,
                n.groupAdjacentWindows
            )
        case .spaceBarExpandActive:
            return spaceBarOnOffRow(
                census,
                o.expandActiveSpace,
                n.expandActiveSpace
            )
        case .spaceBarShowHoverTitles:
            return spaceBarOnOffRow(
                census,
                o.showHoverTitles,
                n.showHoverTitles
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
        case .spaceBarInactiveContent:
            return spaceBarChoiceRow(
                census,
                o.inactiveContent,
                n.inactiveContent,
                AppBarOptions.inactiveContent
            )
        case .spaceBarItemLabel:
            return spaceBarChoiceRow(
                census,
                o.itemLabel,
                n.itemLabel,
                AppBarOptions.itemLabel
            )
        case .spaceBarGlyphSpan:
            return spaceBarRow(
                census,
                trimmed(Double(o.glyphSpan)),
                trimmed(Double(n.glyphSpan))
            )
        case .spaceBarGlyphGap:
            return spaceBarPointsRow(census, o.glyphGap, n.glyphGap)
        case .spaceBarFrontAppTitleCap:
            return spaceBarRow(
                census,
                trimmed(Double(o.frontAppTitleCap)),
                trimmed(Double(n.frontAppTitleCap))
            )
        case .spaceBarActiveDimFactor:
            return spaceBarRow(
                census,
                trimmed(o.activeDimFactor),
                trimmed(n.activeDimFactor)
            )
        case .spaceBarStickyBadge:
            return spaceBarOnOffRow(census, o.stickyBadge, n.stickyBadge)
        case .spaceBarFocusedItemColor:
            return spaceBarHexRow(
                census,
                o.focusedItemColor,
                n.focusedItemColor
            )
        case .spaceBarFocusedHighlightColor:
            return spaceBarRow(
                census,
                bordersAutoHex(o.focusedHighlightColor),
                bordersAutoHex(n.focusedHighlightColor)
            )
        }
    }
}

extension SettingsValueReadout {
    static func spaceBarRow(
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

    static func spaceBarOnOffRow(
        _ census: SettingKey,
        _ old: Bool,
        _ new: Bool
    ) -> [SettingsDiffRow] {
        spaceBarRow(census, onOff(old), onOff(new))
    }

    static func spaceBarPointsRow(
        _ census: SettingKey,
        _ old: CGFloat,
        _ new: CGFloat
    ) -> [SettingsDiffRow] {
        spaceBarRow(census, points(old), points(new))
    }

    /// Readout for size sliders with 0 as Automatic sentinel.
    static func spaceBarAutoPointsRow(
        _ census: SettingKey,
        _ old: CGFloat,
        _ new: CGFloat
    ) -> [SettingsDiffRow] {
        spaceBarRow(census, autoPoints(old), autoPoints(new))
    }

    static func spaceBarChoiceRow<T: Equatable>(
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

    /// Resolves display label from options list.
    private static func spaceBarChoice<T: Equatable>(
        _ value: T,
        _ options: [(T, String)]
    ) -> String {
        options.first { $0.0 == value }?.1
            ?? String(describing: value)
    }

    /// Formats seconds with one decimal place.
    static func spaceBarSeconds(_ ms: Int) -> String {
        L(
            "diff.value.seconds",
            "%1$@ s",
            String(format: "%.1f", Double(ms) / 1000)
        )
    }

    static func spaceBarHexRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        spaceBarRow(census, hexDisplay(old), hexDisplay(new))
    }
}
