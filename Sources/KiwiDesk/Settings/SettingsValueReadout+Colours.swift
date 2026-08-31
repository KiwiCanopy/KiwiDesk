import KiwiDeskCore

/// Colours & Animations settings diff readout generators. The
/// palette rows are ACTIONS — they mutate the palette store,
/// not the draft config — so none stores a value a draft diff
/// could state.
extension SettingsValueReadout {
    static func coloursRows(
        _ key: ColoursKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.colours(key)
        let o = old.settings.animations
        let n = new.settings.animations
        switch key {
        case .animationsMaster:
            // The master is derived, not stored (`anyEnabled`) —
            // the same derivation the Motion card's toggle and
            // the Home card's subtitle read.
            return coloursOnOffRow(
                census,
                o.anyEnabled,
                n.anyEnabled
            )
        case .animationsOnSpaceChange:
            return coloursOnOffRow(
                census,
                o.onSpaceChange,
                n.onSpaceChange
            )
        case .animationsOnWindowResize:
            return coloursOnOffRow(
                census,
                o.onWindowResize,
                n.onWindowResize
            )
        case .animationsOnWindowSwap:
            return coloursOnOffRow(
                census,
                o.onWindowSwap,
                n.onWindowSwap
            )
        case .animationsOnRelayout:
            return coloursOnOffRow(
                census,
                o.onRelayout,
                n.onRelayout
            )
        case .animationsDurationMS:
            return coloursRow(
                census,
                milliseconds(Double(o.durationMS)),
                milliseconds(Double(n.durationMS))
            )
        case .animationsOnScrolling:
            return coloursOnOffRow(
                census,
                o.onScrolling,
                n.onScrolling
            )
        case .animationsScrollDurationMS:
            return coloursRow(
                census,
                milliseconds(Double(o.scrollDurationMS)),
                milliseconds(Double(n.scrollDurationMS))
            )
        case .paletteApply, .paletteSave, .paletteRename,
            .paletteExport, .paletteDelete, .paletteImport,
            .paletteNeonGlowHint:
            // Actions and a link: no stored model path, so no
            // value pair to narrate.
            return []
        }
    }

    private static func coloursRow(
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

    private static func coloursOnOffRow(
        _ census: SettingKey,
        _ old: Bool,
        _ new: Bool
    ) -> [SettingsDiffRow] {
        coloursRow(census, onOff(old), onOff(new))
    }
}
