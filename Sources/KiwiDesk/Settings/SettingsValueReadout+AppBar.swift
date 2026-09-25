import CoreGraphics
import KiwiDeskCore

/// Global App Bar settings diff readout generators (`AppBarOptions`).
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
        case .appBarGroupAdjacentWindows:
            return appBarOnOffRow(
                census,
                o.groupAdjacentWindows,
                n.groupAdjacentWindows
            )
        case .appBarTitleCap:
            return appBarRow(
                census,
                trimmed(Double(o.titleCap)),
                trimmed(Double(n.titleCap))
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
}
