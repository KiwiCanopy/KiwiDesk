import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// What a believed bound MEANS (#677): which ask a layout may
/// swap for the learned answer, and when a window sitting off
/// its target is explained rather than stranded. The believing
/// itself is `SizeBoundLearnerTests`.
@Suite("Effective size bound semantics (#677)")
struct EffectiveSizeBoundTests {
    private let bound = EffectiveSizeBound(
        width: .init(asked: 900, answered: 715)
    )

    @Test("A consumed span answers only the refused ask")
    func consumedSpanMatchesAskOnly() {
        #expect(bound.consumedWidth(asking: 900) == 715)
        // Within the tolerance still counts as the same ask.
        #expect(bound.consumedWidth(asking: 901) == 715)
        // A NEW ask must be probed, not silently swapped: a
        // user who widens the slot past a stale bound must be
        // heard by the app, not by the ledger.
        #expect(bound.consumedWidth(asking: 800) == nil)
        // The unlearned axis never consumes.
        #expect(bound.consumedHeight(asking: 900) == nil)
    }

    @Test("Explains: refused axis at the learned answer")
    func explainsRefusedAxis() {
        // Width re-asks the refused 900 with the window at the
        // learned 715; height already matches.
        #expect(
            bound.explains(
                currentSize: CGSize(width: 715, height: 800),
                targetSize: CGSize(width: 900, height: 800)
            )
        )
    }

    @Test("A new ask is not explained")
    func newAskIsNotExplained() {
        // Target width 800 is not the refused ask — the engine
        // must issue it, whatever the window sits at.
        #expect(
            !bound.explains(
                currentSize: CGSize(width: 715, height: 800),
                targetSize: CGSize(width: 800, height: 800)
            )
        )
    }

    @Test("A window off the learned answer is not explained")
    func strayAnswerIsNotExplained() {
        // Same ask, but the window sits at neither the target
        // nor the learned answer — that is a strand, not a
        // bound, and skipping would freeze it there.
        #expect(
            !bound.explains(
                currentSize: CGSize(width: 600, height: 800),
                targetSize: CGSize(width: 900, height: 800)
            )
        )
    }

    @Test("An unexplained second axis blocks the skip")
    func unexplainedSecondAxisBlocks() {
        // Width is explained but height is genuinely off
        // target with nothing learned about it.
        #expect(
            !bound.explains(
                currentSize: CGSize(width: 715, height: 600),
                targetSize: CGSize(width: 900, height: 800)
            )
        )
    }

    @Test("A floor explains like a ceiling")
    func floorExplains() {
        // The mirror case (#677): slot narrower than the app's
        // minimum — answered above asked.
        let floor = EffectiveSizeBound(
            width: .init(asked: 300, answered: 480)
        )
        #expect(
            floor.explains(
                currentSize: CGSize(width: 480, height: 800),
                targetSize: CGSize(width: 300, height: 800)
            )
        )
        #expect(floor.consumedWidth(asking: 300) == 480)
    }
}
