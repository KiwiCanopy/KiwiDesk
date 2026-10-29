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
        case .shortcutPanelLiquidGlass:
            return coloursOnOffRow(
                census,
                old.settings.shortcutPanelLiquidGlass,
                new.settings.shortcutPanelLiquidGlass
            )
        case .dragLiquidGlass:
            return coloursOnOffRow(
                census,
                old.settings.dragLiquidGlass,
                new.settings.dragLiquidGlass
            )
        case .stickyLiquidGlass:
            return coloursOnOffRow(
                census,
                old.settings.stickyStyle.liquidGlass,
                new.settings.stickyStyle.liquidGlass
            )
        case .lookOrigin:
            // Surfaceless, so the census carries no label to read.
            return [
                .change(
                    census,
                    label: lookOriginLabel,
                    old: lookCredit(old.settings.lookOrigin),
                    new: lookCredit(new.settings.lookOrigin)
                )
            ]
        case .borderSheen:
            return coloursRow(
                census,
                sheen(old.settings.borderStyle.sheen),
                sheen(new.settings.borderStyle.sheen)
            )
        case .liquidGlassMaster:
            // Derived, like the animations master beside it: the
            // one `LiquidGlassAgreement` reading the row shows.
            return coloursOnOffRow(
                census,
                LiquidGlassAgreement(settings: old.settings).allOn,
                LiquidGlassAgreement(settings: new.settings).allOn
            )
        case .spaceTransition, .spaceSlideDuration:
            // No model path: the rows write at once (#1741).
            return []
        case .animationsMaster:
            // The master is derived, not stored (`anyEnabled`) —
            // the same derivation the Motion card's toggle and
            // the Home card's subtitle read.
            return coloursOnOffRow(
                census,
                o.anyEnabled,
                n.anyEnabled
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
        case .animationsOnStateChange:
            return coloursOnOffRow(
                census,
                o.onStateChange,
                n.onStateChange
            )
        case .animationsDurationMS:
            return coloursRow(
                census,
                milliseconds(Double(o.durationMS)),
                milliseconds(Double(n.durationMS))
            )
        case .animationsOnExpand:
            return coloursOnOffRow(census, o.onExpand, n.onExpand)
        case .animationsOnPeek:
            return coloursOnOffRow(census, o.onPeek, n.onPeek)
        case .animationsExpandDurationMS:
            return coloursRow(
                census,
                milliseconds(Double(o.expandDurationMS)),
                milliseconds(Double(n.expandDurationMS))
            )
        case .animationsRevealDurationMS:
            return coloursRow(
                census,
                milliseconds(Double(o.revealDurationMS)),
                milliseconds(Double(n.revealDurationMS))
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
            .paletteNeonGlowHint, .lookApply, .lookKeepPreviousColors,
            .lookAppliesTo,
            .lookSave, .lookImport, .lookRename, .lookExport,
            .lookDelete, .accentPaint, .secondAccentPaint:
            // Actions and a link: no stored model path, so no
            // value pair to narrate — a group colour's writes are
            // booked to the rows it painted (#1857).
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

extension SettingsValueReadout {
    /// The origin's diff row label.
    static var lookOriginLabel: String {
        L("looks.origin", "Look credit")
    }

    /// The look an origin credits, as a diff row reads it.
    static func lookCredit(_ origin: ShelfLook?) -> String {
        guard let origin else { return L("looks.origin.none", "None") }
        guard let author = origin.author else { return origin.name }
        return L("looks.origin.by", "%1$@ by %2$@", origin.name, author)
    }
}
