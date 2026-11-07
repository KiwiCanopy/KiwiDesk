import KiwiDeskCore

/// The Maximize card's diff rows (#3062).
extension SettingsValueReadout {
    static func maximizeRows(
        _ key: BehaviourKey,
        _ census: SettingKey,
        _ before: TilingSettings,
        _ after: TilingSettings
    ) -> [SettingsDiffRow] {
        let old = before.maximize
        let new = after.maximize
        switch key {
        case .maximizeHeightShare:
            return [
                .change(
                    census,
                    label: label(for: census),
                    old: percent(old.heightShare),
                    new: percent(new.heightShare)
                )
            ]
        case .maximizeWidthShare:
            return [
                .change(
                    census,
                    label: label(for: census),
                    old: percent(old.widthShare),
                    new: percent(new.widthShare)
                )
            ]
        default:
            return [
                .change(
                    census,
                    label: label(for: census),
                    old: MaximizeCard.anchorName(old.anchor),
                    new: MaximizeCard.anchorName(new.anchor)
                )
            ]
        }
    }
}
