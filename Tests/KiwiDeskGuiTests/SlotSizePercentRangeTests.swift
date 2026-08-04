import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

// The scrolling slot-size Percent slider against the model it
// writes into: the slider spans exactly what `ScrollSize` will
// store, at a granularity fine enough that the shipped standard
// is a stop the user can drag back to.

@Suite("Slot size percent range")
struct SlotSizePercentRangeTests {
    @Test("The slider spans exactly what the model stores")
    func rangeMatchesTheModel() {
        // A stop below `minFraction` would write a percentage the
        // setter refuses to keep — the control would report a
        // value the config does not hold. Above, a full-axis slot
        // is renderable, so nothing is withheld.
        #expect(
            SlotSizeRows.percentRange.lowerBound
                == ScrollSize.minFraction * 100
        )
        #expect(
            SlotSizeRows.percentRange.upperBound
                == ScrollSize.maxFraction * 100
        )
    }

    @Test("The shipped standard is a stop the slider can return to")
    func defaultIsReachable() {
        let standard = ScrollSize.autoHorizontalFraction * 100
        #expect(SlotSizeRows.percentRange.contains(standard))
        let steps =
            (standard - SlotSizeRows.percentRange.lowerBound)
            / SlotSizeRows.percentStep
        #expect(abs(steps - steps.rounded()) < 0.0001)
    }

    @Test("A step moves a visible amount of window")
    func stepIsPerceptible() {
        // The slot resolves against the axis, so one step is
        // `step%` of it — on the narrowest display this app
        // targets that is still tens of points, which is why the
        // percent slider can afford a finer step than the pt one.
        let narrowAxis = 1280.0
        let perStep = narrowAxis * SlotSizeRows.percentStep / 100
        #expect(perStep >= 10)
    }

    @Test("Both orientations share one standard")
    func oneStandardPerAxis() {
        // The unit picker drops its "Default" segment on this
        // equality (`SlotSizeRows`' own note): Percent can render
        // `.auto` truthfully only while one number covers both
        // axes.
        #expect(
            ScrollSize.autoHorizontalFraction
                == ScrollSize.autoVerticalFraction
        )
    }
}
