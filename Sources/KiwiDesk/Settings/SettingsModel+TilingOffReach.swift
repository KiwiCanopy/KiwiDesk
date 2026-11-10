import KiwiDeskCore

/// The Tiling off rows' values and checklists (#3089). The page
/// holds the profile's own value, nil where it follows the shared
/// one, which is `gui.json`'s app-wide base.
extension SettingsModel {
    typealias TilingTable = RuleReachTable<Bool>

    /// The shared start value as stored: the snapshot's base, or
    /// the live app-wide value where no checklist reads one.
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

    /// `settings` with each tiling-off value the draft moved for
    /// `profile` as the encoded tables leave its own: nil where it
    /// follows. What a live Save commits and the sidecar carries,
    /// so neither bakes a shared value in as the profile's own; a
    /// value the draft left as stored stays as it is.
    func sparseTilingToggle(
        _ settings: TilingToggleSettings,
        in reach: RuleReachSnapshot,
        for profile: String
    ) -> TilingToggleSettings {
        var toggle = settings
        let stored = ruleReachStored
        func own(
            _ table: TilingTable,
            _ storedTable: TilingTable?,
            _ key: String,
            _ page: Bool?,
            _ base: Bool
        ) -> Bool? {
            let entry = storedTable?.entries[profile]?[key] ?? nil
            let moved =
                table.touched[profile]?.contains(key) == true
                || table.baseTouched.contains(key) || page != entry
            guard moved else { return page }
            return table.tilingOverride(key, for: profile, fallback: base)
        }
        let startKey = TilingTable.tilingStartKey
        toggle.start = own(
            reach.tilingStart,
            stored?.tilingStart,
            startKey,
            settings.start,
            tilingStartBase
        )
        let borders = TilingTable.offHidesBordersKey
        toggle.offHidesBorders = own(
            reach.tilingOffHides,
            stored?.tilingOffHides,
            borders,
            settings.offHidesBorders,
            tilingOffHidesBase(borders)
        )
        let bars = TilingTable.offHidesBarsKey
        toggle.offHidesBars = own(
            reach.tilingOffHides,
            stored?.tilingOffHides,
            bars,
            settings.offHidesBars,
            tilingOffHidesBase(bars)
        )
        return toggle
    }
}
