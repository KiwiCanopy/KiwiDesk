import KiwiDeskCore

/// The Tiling off rows' values and checklists (#3089). The page
/// holds the profile's own value, nil where it follows the shared
/// one, which is `gui.json`'s app-wide base.
extension SettingsModel {
    typealias TilingTable = RuleReachTable<Bool>

    /// The shared start value as stored — the base the tables
    /// encode against and the readout narrates — or the live value
    /// where no checklist reads one (a Lua-owned config).
    var tilingStartBase: Bool {
        ruleReachStored?.tilingStart.tilingBase(
            TilingTable.tilingStartKey,
            fallback: appWide.tilingStartGlobal
        ) ?? appWide.tilingStartGlobal
    }

    /// The shared value of a hide tick, as `tilingStartBase`.
    func tilingOffHidesBase(_ key: String) -> Bool {
        let live =
            key == TilingTable.offHidesBordersKey
            ? appWide.tilingOffHidesBorders : appWide.tilingOffHidesBars
        return ruleReachStored?.tilingOffHides.tilingBase(
            key,
            fallback: live
        ) ?? live
    }

    /// The start row's switch: the page's own value over the base.
    var tilingStartOn: Bool {
        config.settings.tiling.start ?? tilingStartBase
    }

    /// A hide row's switch, as `tilingStartOn`.
    func tilingOffHidesOn(_ key: String) -> Bool {
        let own =
            key == TilingTable.offHidesBordersKey
            ? config.settings.tiling.offHidesBorders
            : config.settings.tiling.offHidesBars
        return own ?? tilingOffHidesBase(key)
    }

    /// The start row's checklist.
    func tilingStartReach() -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        let key = TilingTable.tilingStartKey
        return reading(
            reach.tilingStart,
            key,
            reach.unreadable,
            picked: reachEdits.reach[.tilingStart]?[key],
            TilingOffWords.onOff
        )
    }

    /// A hide row's checklist, keyed by its tick.
    func tilingOffHidesReach(_ key: String) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(
            reach.tilingOffHides,
            key,
            reach.unreadable,
            picked: reachEdits.reach[.tilingOffHides]?[key],
            TilingOffWords.onOff
        )
    }

    /// The page's values as the tables key them, each over the
    /// stored base, so a page that follows reads as the base.
    func tilingStartPage(
        _ toggle: TilingToggleSettings,
        over table: TilingTable
    ) -> [String: Bool] {
        let key = TilingTable.tilingStartKey
        return [
            key: toggle.start
                ?? table.tilingBase(key, fallback: tilingStartBase)
        ]
    }

    /// The hide family's page values, as `tilingStartPage`.
    func tilingOffHidesPage(
        _ toggle: TilingToggleSettings,
        over table: TilingTable
    ) -> [String: Bool] {
        let borders = TilingTable.offHidesBordersKey
        let bars = TilingTable.offHidesBarsKey
        return [
            borders: toggle.offHidesBorders
                ?? table.tilingBase(
                    borders,
                    fallback: tilingOffHidesBase(borders)
                ),
            bars: toggle.offHidesBars
                ?? table.tilingBase(bars, fallback: tilingOffHidesBase(bars)),
        ]
    }

    /// The page's own tiling-off values as the encoded tables
    /// leave them, nil where it follows: what the sidecar carries.
    /// The tables are Core's to write (`saveRuleReach`), so this
    /// reads their entries and decides nothing.
    func encodedTilingToggle(
        _ settings: TilingToggleSettings,
        in reach: RuleReachSnapshot,
        for profile: String
    ) -> TilingToggleSettings {
        var toggle = settings
        let start = reach.tilingStart
        let hides = reach.tilingOffHides
        toggle.start = start.tilingOwn(
            TilingTable.tilingStartKey,
            for: profile
        )
        toggle.offHidesBorders = hides.tilingOwn(
            TilingTable.offHidesBordersKey,
            for: profile
        )
        toggle.offHidesBars = hides.tilingOwn(
            TilingTable.offHidesBarsKey,
            for: profile
        )
        return toggle
    }

    /// `committing` with the tiling-off values live holds now: with
    /// a checklist those are the tables', which `saveRuleReach`
    /// writes and live then follows, so the commit takes none of the
    /// page's (#3089).
    func keepingLiveTilingToggle(
        _ committing: TilingToggleSettings
    ) -> TilingToggleSettings {
        guard encodedReach != nil else { return committing }
        let live = core.tiler.settings.tiling
        var toggle = committing
        toggle.start = live.start
        toggle.offHidesBorders = live.offHidesBorders
        toggle.offHidesBars = live.offHidesBars
        return toggle
    }
}
