import Foundation

extension KiwiCore {
    /// The load's tail for `init.lua`'s splits (#3573): a screen
    /// the last load split and this one no longer names goes
    /// whole, once, through the same merge a `set_display_areas`
    /// with no sizes takes. `kept` is false when a profile
    /// replaced the settings, whose splits are then its own.
    /// A held settings call of a load whose settings a profile
    /// replaced is dropped, as the replace would have overwritten
    /// it live (#3640).
    func settleLuaAreaSplits(kept: Bool) {
        if !kept { heldScreenCalls.removeAll(where: \.isSettings) }
        makeWhole(
            luaAreaSplits.endLoad(
                stored: tiler.settings.displayAreas,
                kept: kept,
                holding: heldScreenCalls.contains(where: \.isSplit)
            )
        )
    }

    /// The deferred tail of a load that held a split, once the
    /// drain stored it (#3640).
    func settleHeldLuaAreaSplits() {
        makeWhole(
            luaAreaSplits.endHeld(stored: tiler.settings.displayAreas)
        )
    }

    private func makeWhole(_ dropped: [String]) {
        for key in dropped {
            guard let number = ScreenSlotKey(parsing: key)?.number,
                let previous = tiler.settings.displayAreas[key]
            else { continue }
            storeShares(.whole(after: previous), number: number)
        }
    }
}
