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
        // Never past the share's own floor, which the write clamps
        // to: a 100 pt minimum on a wide screen would fit 25. The
        // ceiling is derived — the last count whose share is legal.
        let ceiling = ScrollSize.countCeiling
        #expect(1 / Double(ceiling) >= ScrollSize.minFraction)
        #expect(1 / Double(ceiling + 1) < ScrollSize.minFraction)
        #expect(
            ScrollSize.maxCount(along: 2560, gap: 0, minimum: 100) == ceiling
        )
    }

    @Test("the count's share reads back, and the steps from — land")
    func countShareAndSteps() {
        // What the stepper writes is what the wire decodes, so a
        // stored third re-read from disk is the same value.
        for n in 1...20 {
            #expect(ScrollSize.count(of: ScrollSize.share(of: n)) == n)
        }
        #expect(ScrollSize.share(of: 3) == 0.3333)
        #expect(ScrollSize.share(of: 2) == 0.5)
        // From the shipped 95%: ▲ the first whole count above,
        // ▼ the first below — never "nearest".
        #expect(ScrollSize.countAbove(0.95) == 2)
        #expect(ScrollSize.countBelow(0.95) == 1)
        #expect(ScrollSize.countAbove(0.3) == 4)
        #expect(ScrollSize.countBelow(0.3) == 3)
        // 1/0.15 = 6.67: ▼ floors to 6, never rounds to 7.
        #expect(ScrollSize.countBelow(0.15) == 6)
        // A whole share is its own count both ways.
        #expect(ScrollSize.countAbove(0.25) == 4)
        #expect(ScrollSize.countBelow(0.25) == 4)
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
            settings.scrollingColumnCap(bounds: visible, space: SpaceID("1"))
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
            settings.scrollingColumnCap(bounds: visible, space: SpaceID("1"))
                == 5
        )
        // A per-space gap override is the space's own.
        settings.gapsOverride[SpaceID("2")] = Gaps(
            outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
            inner: Gaps.Inner(horizontal: 10, vertical: 10)
        )
        #expect(
            settings.scrollingColumnCap(bounds: visible, space: SpaceID("2"))
                == 6
        )
        // Vertical orientation counts rows on the height.
        settings.scrolling.orientation = .vertical
        #expect(
            settings.scrollingColumnCap(bounds: visible, space: SpaceID("2"))
                == 3
        )
        // The app bar's strip is carved too: 100 pt off the left
        // takes the horizontal count from six to five.
        settings.scrolling.orientation = .horizontal
        settings.gapsGlobal.outer = Gaps.Outer(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0
        )
        settings.scrolling.appBar.enabled = true
        settings.kiwishelf.edge = .left
        settings.kiwishelf.thickness = 100
        #expect(
            settings.scrollingColumnCap(bounds: visible, space: SpaceID("1"))
                == 5
        )
        settings.scrolling.appBar.enabled = false
        settings.gapsGlobal.outer = Gaps.Outer(
            top: 0,
            bottom: 0,
            left: 40,
            right: 40
        )
        settings.scrolling.orientation = .vertical
        // A space's own scrolling override — vertical here, over a
        // horizontal global — is the axis its count is read on.
        settings.scrolling.orientation = .horizontal
        var vertical = ScrollingOverride()
        vertical.orientation = .vertical
        settings.scrolling.override[SpaceID("2")] = vertical
        #expect(
            settings.scrollingColumnCap(bounds: visible, space: SpaceID("2"))
                == 3
        )
        #expect(
            settings.scrollingColumnCap(bounds: visible, space: SpaceID("1"))
                == 5
        )
        settings.scrolling.override[SpaceID("2")] = nil
        settings.scrolling.orientation = .vertical
        // No space resolves the globals — the 40 pt outer gaps —
        // and never any space's override.
        #expect(
            settings.scrollingColumnCap(bounds: visible, space: nil) == 3
        )
        settings.scrolling.orientation = .horizontal
        #expect(
            settings.scrollingColumnCap(bounds: visible, space: nil) == 5
        )
    }
}
