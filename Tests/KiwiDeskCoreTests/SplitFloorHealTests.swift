import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The split stores' floor heal math (#934/#1430) — the
/// `TrackFloorHealTests` shape one store over. The wiring over a
/// real core is `SplitFloorHealWiringTests`, the cue
/// `SplitFloorCueTests`, the inward post-pass
/// `SplitOverflowTests`.
@Suite("Split floor heal math (#934)")
struct SplitFloorHealTests {
    private func healed(
        _ verdict: SplitDomain.FloorHealVerdict?
    ) -> Double? {
        if case .healed(let ratio) = verdict { return ratio }
        return nil
    }

    @Test("A low side under its learned floor heals to the edge plus margin")
    func lowSideHeals() throws {
        // 1170 pt at 0.5 draws 585 each; a 700 pt floor on the
        // low side lands at 700.25.
        let ratio = try #require(
            healed(
                SplitDomain.healedRatio(
                    current: 0.5,
                    available: 1170,
                    globalFloor: 300,
                    low: .init(size: 700, learned: true),
                    high: .init(size: 300, learned: false),
                    margin: 0.25
                )
            )
        )
        #expect(abs(ratio * 1170 - 700.25) < 0.01)
    }

    @Test("A high side under its learned floor heals to the upper edge")
    func highSideHeals() throws {
        let ratio = try #require(
            healed(
                SplitDomain.healedRatio(
                    current: 0.5,
                    available: 1170,
                    globalFloor: 300,
                    low: .init(size: 300, learned: false),
                    high: .init(size: 700, learned: true),
                    margin: 0.25
                )
            )
        )
        #expect(abs((1 - ratio) * 1170 - 700.25) < 0.01)
    }

    @Test("A ratio already drawing the floor is never rewritten")
    func legalRatioIsNil() {
        // 0.7 draws 819 on the low side: above the floor.
        #expect(
            SplitDomain.healedRatio(
                current: 0.7,
                available: 1170,
                globalFloor: 300,
                low: .init(size: 700, learned: true),
                high: .init(size: 300, learned: false),
                margin: 0.25
            ) == nil
        )
    }

    @Test("A side within the tolerance of its floor is not re-healed")
    func toleranceUnderTheFloorIsNil() {
        // 699 against a 700 learned floor is the same span
        // (#677's quantum): rewriting it would churn every retile.
        #expect(
            SplitDomain.healedRatio(
                current: 699.0 / 1170.0,
                available: 1170,
                globalFloor: 300,
                low: .init(size: 700, learned: true),
                high: .init(size: 300, learned: false),
                margin: 0.25
            ) == nil
        )
    }

    @Test("Only a learned floor moves a store")
    func unlearnedFloorNeverHeals() {
        // The same numbers, but nothing learned: the render
        // clamp's business, never a rewrite (#383).
        #expect(
            SplitDomain.healedRatio(
                current: 0.5,
                available: 1170,
                globalFloor: 300,
                low: .init(size: 700, learned: false),
                high: .init(size: 300, learned: false),
                margin: 0.25
            ) == nil
        )
    }

    @Test("The stored ratio is judged where the render pins it")
    func drawnReadingIsTheRenderClamp() {
        // 0.05 cannot be drawn: the render pins the low side at
        // the 300 pt global floor (#383), which is inside the
        // tolerance of a 301 pt learned floor — nothing sinks.
        // Judged raw, 58 pt would sink and the heal would churn.
        #expect(
            SplitDomain.healedRatio(
                current: 0.05,
                available: 1170,
                globalFloor: 300,
                low: .init(size: 301, learned: true),
                high: .init(size: 300, learned: false),
                margin: 0.25
            ) == nil
        )
    }

    @Test("Unfit names the binding side")
    func unfitNamesTheBindingSide() {
        // Two 700 pt floors on 1170: both sink at 0.5, the low
        // side overhangs and the high side binds.
        #expect(
            SplitDomain.healedRatio(
                current: 0.5,
                available: 1170,
                globalFloor: 300,
                low: .init(size: 700, learned: true),
                high: .init(size: 700, learned: true),
                margin: 0.25
            ) == .unfit(bindingLow: false)
        )
        // At 0.6 only the high side sinks: the low side binds.
        #expect(
            SplitDomain.healedRatio(
                current: 0.6,
                available: 1170,
                globalFloor: 300,
                low: .init(size: 700, learned: true),
                high: .init(size: 700, learned: true),
                margin: 0.25
            ) == .unfit(bindingLow: true)
        )
    }

    @Test("Margins that cannot fit never write the boundary")
    func marginsThatCannotFitAreUnfit() {
        // 1000 holds 600 + 400 exactly and not the margins: the
        // exact boundary is the render's pile line (#925).
        #expect(
            SplitDomain.healedRatio(
                current: 0.5,
                available: 1000,
                globalFloor: 300,
                low: .init(size: 600, learned: true),
                high: .init(size: 400, learned: true),
                margin: 0.25
            ) == .unfit(bindingLow: false)
        )
        #expect(
            healed(
                SplitDomain.healedRatio(
                    current: 0.5,
                    available: 1000,
                    globalFloor: 300,
                    low: .init(size: 600, learned: true),
                    high: .init(size: 400, learned: true),
                    margin: 0
                )
            ) == 0.6
        )
    }

    @Test("A region the render piles is left alone")
    func pileRegionIsNil() {
        #expect(
            SplitDomain.healedRatio(
                current: 0.5,
                available: 500,
                globalFloor: 300,
                low: .init(size: 400, learned: true),
                high: .init(size: 300, learned: false),
                margin: 0.25
            ) == nil
        )
    }
}
