import KiwiDeskCore

/// The Tiling off rows' readouts (#3089): a profile's own value
/// reads On or Off, an unset one "follows All profiles" with the
/// shared value it resolves to, read from the config's own
/// app-wide group.
extension SettingsValueReadout {
    static func tilingRows(
        _ key: BehaviourKey,
        _ census: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        guard let read = own(key) else { return [] }
        return [
            .change(
                census,
                label: label(for: census),
                old: tilingValue(read(old.settings.tiling), base(key, old)),
                new: tilingValue(read(new.settings.tiling), base(key, new))
            )
        ]
    }

    /// `own` On or Off, or the follow and the value it resolves to.
    static func tilingValue(_ own: Bool?, _ base: Bool) -> String {
        own.map(TilingOffWords.onOff)
            ?? L(
                "space_override.inherits_page",
                "follows %1$@ · %2$@",
                L("app_rules.reach.all", "All profiles"),
                TilingOffWords.onOff(base)
            )
    }

    private static func own(
        _ key: BehaviourKey
    ) -> ((TilingToggleSettings) -> Bool?)? {
        switch key {
        case .tilingStart: \.start
        case .tilingOffHidesBorders: \.offHidesBorders
        case .tilingOffHidesBars: \.offHidesBars
        default: nil
        }
    }

    /// The shared value `config` carries, the default where it
    /// stores none yet.
    private static func base(_ key: BehaviourKey, _ config: GuiConfig) -> Bool
    {
        let wide = config.appWide ?? AppWideSettings()
        return switch key {
        case .tilingOffHidesBorders: wide.tilingOffHidesBorders
        case .tilingOffHidesBars: wide.tilingOffHidesBars
        default: wide.tilingStartGlobal
        }
    }
}
