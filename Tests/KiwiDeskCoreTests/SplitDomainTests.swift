import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure split-domain math (#44/#383) shared by the stack's
/// master/stack split and every BSP split: the ratio range that
/// keeps both sides ≥ min, and the interactive write cap that
/// never pushes an out-of-range value back across its base. One
/// authority so the two layouts' clamps cannot drift (§5).
@Suite("Split-domain ratio math (#44/#383)")
struct SplitDomainTests {
    @Test("effectiveRatioRange fences both sides at min")
    func effectiveRange() throws {
        // 1000 wide, min 300 → fraction 0.3 → [0.3, 0.7].
        let range = try #require(
            SplitDomain.effectiveRatioRange(
                available: 1000,
                minSize: 300
            )
        )
        #expect(abs(range.lowerBound - 0.3) < 1e-9)
        #expect(abs(range.upperBound - 0.7) < 1e-9)
    }

    @Test("Too narrow for two min-size sides has no range")
    func noRangeWhenTooNarrow() {
        // 500 < 2·300 → cannot split; nil signals the cascade.
        #expect(
            SplitDomain.effectiveRatioRange(
                available: 500,
                minSize: 300
            ) == nil
        )
    }

    @Test("A grow past the cliff stops at the upper bound")
    func growCapsAtUpperBound() {
        let value = SplitDomain.cappedRatioWrite(
            0.95,
            base: 0.5,
            available: 1000,
            minSize: 300
        )
        #expect(abs(value - 0.7) < 1e-9)
    }

    @Test("A shrink past the cliff stops at the lower bound")
    func shrinkCapsAtLowerBound() {
        let value = SplitDomain.cappedRatioWrite(
            0.05,
            base: 0.5,
            available: 1000,
            minSize: 300
        )
        #expect(abs(value - 0.3) < 1e-9)
    }

    @Test("An already-out-of-range value stays editable inward")
    func outOfRangeStaysEditableInward() {
        // Base already beyond the cliff (0.85 > 0.7): a further
        // grow freezes at the base (no invisible ratchet further
        // out), but the value is NOT pushed back to 0.7 either —
        // a shrink toward the range is honored so it can escape.
        let grow = SplitDomain.cappedRatioWrite(
            0.9,
            base: 0.85,
            available: 1000,
            minSize: 300
        )
        #expect(abs(grow - 0.85) < 1e-9)
        let shrink = SplitDomain.cappedRatioWrite(
            0.6,
            base: 0.85,
            available: 1000,
            minSize: 300
        )
        #expect(abs(shrink - 0.6) < 1e-9)
    }

    @Test("No range (too narrow) leaves the write uncapped")
    func uncappedWhenNoRange() {
        let value = SplitDomain.cappedRatioWrite(
            0.95,
            base: 0.5,
            available: 500,
            minSize: 300
        )
        #expect(abs(value - 0.95) < 1e-9)
    }
}
