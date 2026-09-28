import Foundation
import Testing

@testable import KiwiDeskCore

/// A tour Revert returns exactly what a paint reached (#1720), for
/// every bundled look and every palette, over a user's settings
/// that differ from the defaults wherever `ShelfLook.apply`
/// writes beyond a look's keys — every glass leaf apart, every
/// per-layout App Bar override set. A new write `apply` makes
/// beyond its keys reds here until `KiwiCore.unpainted` returns
/// it too.
@Suite("A tour Revert round-trips every look (#1720)")
@MainActor
struct ShelfPaintRoundTripTests {
    private func tunedSettings() -> TilingSettings {
        var settings = TilingSettings()
        let leaves = TilingSettings.liquidGlassLeaves
        for (index, leaf) in leaves.enumerated() {
            settings[keyPath: leaf] = index.isMultiple(of: 2)
        }
        for host in [
            \TilingSettings.monocle.appBar,
            \TilingSettings.scrolling.appBar,
        ] {
            settings[keyPath: host].activeIndicator = .outline
            settings[keyPath: host].content = .icon
            settings[keyPath: host].titleCap = 17
            settings[keyPath: host].groupAdjacentWindows = false
        }
        return settings
    }

    @Test("painting then reverting any pick changes nothing")
    func revertRoundTripsEveryLook() {
        let before = tunedSettings()
        let palettes = makeTestCore().allPalettes
        let looks = LookCatalog.bundled(sizes: [])
        #expect(!looks.isEmpty && !palettes.isEmpty)
        for look in looks {
            for palette in palettes {
                let painted = KiwiCore.painted(
                    before,
                    look: look,
                    palette: palette
                )
                let reverted = KiwiCore.unpainted(painted, to: before)
                #expect(
                    reverted == before,
                    "\(look.name) + \(palette.name) did not revert"
                )
            }
        }
    }
}
