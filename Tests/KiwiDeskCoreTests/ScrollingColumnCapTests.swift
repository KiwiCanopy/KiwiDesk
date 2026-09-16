import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Settings stepper's Core half (#1382): a share IS a count
/// exactly when it is `1/n` at the wire's precision, and the ▲
/// bound is how many slots of the pitch fit the screen at the
/// minimum window size — derived from the layout's own terms.
@Suite("Scrolling column count and cap (#1382)")
struct ScrollingColumnCapTests {
    @Test("a share is a count at the wire's precision")
    func countOfShare() {
        #expect(ScrollSize.count(of: 0.5) == 2)
        #expect(ScrollSize.count(of: 1.0 / 3) == 3)
        #expect(ScrollSize.count(of: 0.3333) == 3)
        #expect(ScrollSize.count(of: 0.25) == 4)
        #expect(ScrollSize.count(of: 1) == 1)
        // Off-count: the shipped 95%, and a hair off a third.
        #expect(ScrollSize.count(of: 0.95) == nil)
        #expect(ScrollSize.count(of: 0.34) == nil)
        #expect(ScrollSize.count(of: 0) == nil)
        // Round-trip: the count writes a share that reads back.
        for n in 1...20 {
            #expect(ScrollSize.count(of: 1 / Double(n)) == n)
        }
    }

    @Test("the cap counts slots of the pitch at the minimum size")
    func maxCount() {
        // 1920 across, 10 pt gaps, 300 pt minimum: 6 × 300 + 5 × 10
        // = 1850 fits, 7 × 300 + 6 × 10 = 2160 does not.
        #expect(ScrollSize.maxCount(along: 1920, gap: 10, minimum: 300) == 6)
        // The gap counts: at 37 pt only 5 fit.
        #expect(ScrollSize.maxCount(along: 1920, gap: 37, minimum: 300) == 5)
        // Never below one slot.
        #expect(ScrollSize.maxCount(along: 200, gap: 10, minimum: 300) == 1)
        // The slider's own floor is the no-screen edge.
        #expect(ScrollSize.fallbackMaxCount == 20)
    }

    @Test("the door derives from the layout's own carve")
    func doorReadsTheCarve() {
        var settings = TilingSettings()
        settings.minWindowSize = 300
        settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
            inner: Gaps.Inner(horizontal: 10, vertical: 10)
        )
        settings.scrolling.appBar.enabled = false
        settings.spaceBarStyle.enabled = false
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        #expect(
            settings.scrollingColumnCap(visible: visible, space: SpaceID("1"))
                == 6
        )
        // Outer gaps narrow the carve: 60 pt off leaves five.
        settings.gapsGlobal.outer = Gaps.Outer(
            top: 0,
            bottom: 0,
            left: 40,
            right: 40
        )
        #expect(
            settings.scrollingColumnCap(visible: visible, space: SpaceID("1"))
                == 5
        )
        // A per-space gap override is the space's own.
        settings.gapsOverride[SpaceID("2")] = Gaps(
            outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
            inner: Gaps.Inner(horizontal: 10, vertical: 10)
        )
        #expect(
            settings.scrollingColumnCap(visible: visible, space: SpaceID("2"))
                == 6
        )
        // Vertical orientation counts rows on the height.
        settings.scrolling.orientation = .vertical
        #expect(
            settings.scrollingColumnCap(visible: visible, space: SpaceID("2"))
                == 3
        )
    }
}
