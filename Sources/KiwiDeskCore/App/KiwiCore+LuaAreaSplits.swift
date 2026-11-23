import Foundation

extension KiwiCore {
    /// The load's tail for `init.lua`'s splits (#3573): a screen
    /// the last load split and this one no longer names goes
    /// whole, once, through the same merge a `set_display_areas`
    /// with no sizes takes. `kept` is false when a profile
    /// replaced the settings, whose splits are then its own.
    func settleLuaAreaSplits(kept: Bool) {
        let dropped = luaAreaSplits.endLoad(
            stored: tiler.settings.displayAreas,
            kept: kept
        )
        for fingerprint in dropped {
            guard let screen = splitScreen(.string(fingerprint))
            else { continue }
            storeSplit(
                ScreenSplit.whole(
                    width: screen.width,
                    height: screen.height,
                    after: tiler.settings.displayAreas[fingerprint]
                ),
                on: fingerprint
            )
        }
    }
}
