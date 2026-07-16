import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// Per-window vertical weights in the stack column (#67):
/// `column()` distributes proportionally to `stackWeights`,
/// defaulting to an even split, and falls back to the existing
/// overflow cascade when a weighted share stops fitting.
@Suite("Stack per-window weights (#67)")
struct StackWeightTests {
    let layout = StackLayout()

    private func makeContext(
        weights: [WindowID: Double] = [:],
        minWindowSize: CGFloat = 100
    ) -> LayoutContext {
        LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(10),
            minWindowSize: minWindowSize,
            stackWeights: weights
        )
    }

    @Test("No weights = the even split of old")
    func defaultIsEven() throws {
        // Master + two stack windows: the stack column halves.
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: makeContext()
        )
        let b = try #require(frames[w2])
        let c = try #require(frames[w3])
        #expect(abs(b.height - c.height) < 0.01)
        #expect(abs(b.height - (1060 - 10) / 2) < 0.01)
    }

    @Test("A weighted window takes its share of the column")
    func weightedShare() throws {
        // w2 weighs 2, w3 defaults to 1 → 2:1 in the column.
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: makeContext(weights: [w2: 2])
        )
        let b = try #require(frames[w2])
        let c = try #require(frames[w3])
        let available: CGFloat = 1060 - 10
        #expect(abs(b.height - available * 2 / 3) < 0.01)
        #expect(abs(c.height - available * 1 / 3) < 0.01)
        // The column still tiles top to bottom, no overlap.
        #expect(abs(c.minY - b.maxY - 10) < 0.01)
    }

    @Test("Weights only shift the focused column, not the master")
    func masterUntouched() throws {
        let even = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: makeContext()
        )
        let weighted = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: makeContext(weights: [w2: 3])
        )
        #expect(even[w1] == weighted[w1])
    }

    @Test("A weighted share below min falls back to overflow")
    func overflowFallback() throws {
        // Evenly the column fits (525 each ≥ 300), but a 9:1
        // weighting starves w3 (105 < 300) → cascade path,
        // which tiles evenly and cascades the overflow.
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: makeContext(
                weights: [w2: 9],
                minWindowSize: 300
            )
        )
        let b = try #require(frames[w2])
        let c = try #require(frames[w3])
        // Overflow signature: weights are ignored — nothing
        // shrinks below min (weighted math would give w3 only
        // ~105 pt) and w2 gets the even-overflow 750, not its
        // weighted 945.
        #expect(c.height >= 300)
        #expect(b.height < (1060 - 10) * 0.8)
    }

    @Test("Space.remove prunes the window's weight")
    func removePrunes() {
        var space = Space(
            id: "1",
            mode: .stack,
            windows: [w1, w2],
            stackWeights: [w1: 2, w2: 3]
        )
        space.remove(w1)
        #expect(space.stackWeights[w1] == nil)
        #expect(space.stackWeights[w2] == 3)
    }

    @Test("A cross-space move prunes the weight too")
    func crossSpaceMovePrunes() {
        var manager = WorkspaceManager()
        manager.ensureSpace("1", mode: .stack)
        manager.ensureSpace("2", mode: .stack)
        manager.add(w1, to: "1")
        manager.withSpace("1") { $0.stackWeights[w1] = 2 }
        manager.add(w1, to: "2")
        // The weight was a fact about w1's old column; it must
        // not follow the window or linger behind.
        #expect(
            manager[SpaceID("1")]?.stackWeights.isEmpty == true
        )
        #expect(
            manager[SpaceID("2")]?.stackWeights.isEmpty == true
        )
    }
}

/// The master/stack partition helper is the single authority
/// shared by `calculateGeometry` and the resize command (#67
/// review) — pin its shape so a drift in either consumer is a
/// test failure, not a silent reweight of the wrong column.
@Suite("Stack partition authority (#67)")
struct StackPartitionTests {
    @Test("Partition splits at the master boundary")
    func partitionSplits() {
        let (master, stack) = StackLayout.partition(
            [w1, w2, w3],
            masterCount: 1
        )
        #expect(Array(master) == [w1])
        #expect(stack.map(Array.init) == [w2, w3])
    }

    @Test("Everything fits in master → single column")
    func masterOnly() {
        let (master, stack) = StackLayout.partition(
            [w1, w2],
            masterCount: 5
        )
        #expect(Array(master) == [w1, w2])
        #expect(stack == nil)
    }

    @Test("A zero master count clamps to one")
    func zeroClampsToOne() {
        let (master, stack) = StackLayout.partition(
            [w1, w2],
            masterCount: 0
        )
        #expect(Array(master) == [w1])
        #expect(stack.map(Array.init) == [w2])
    }

    @Test("column(containing:) picks the member's zone")
    func columnContaining() {
        let windows = [w1, w2, w3]
        let master = StackLayout.column(
            containing: w1,
            in: windows,
            masterCount: 1
        )
        #expect(master.map(Array.init) == [w1])
        let stack = StackLayout.column(
            containing: w3,
            in: windows,
            masterCount: 1
        )
        #expect(stack.map(Array.init) == [w2, w3])
        #expect(
            StackLayout.column(
                containing: WindowID(99),
                in: windows,
                masterCount: 1
            ) == nil
        )
    }

    @Test("Partition agrees with the layout's rendered zones")
    func partitionMatchesLayout() throws {
        // The net over the mirror: the zones the layout draws
        // are exactly the partition's slices — same x for
        // members of one zone, different x across zones.
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(10),
            minWindowSize: 100
        )
        context.stack.masterCount = 2
        // Pin the vertical master column: the same-x-per-zone
        // net below is meaningless for side-by-side masters.
        context.stack.masterOrientation = .vertical
        let windows = [w1, w2, w3]
        let frames = StackLayout().calculateGeometry(
            for: windows,
            in: context
        )
        let (master, stack) = StackLayout.partition(
            windows,
            masterCount: 2
        )
        let masterXs = Set(
            master.compactMap { frames[$0]?.minX }
        )
        let stackXs = Set(
            (stack ?? []).compactMap { frames[$0]?.minX }
        )
        #expect(masterXs.count == 1)
        #expect(stackXs.count == 1)
        #expect(masterXs != stackXs)
    }
}

/// The shared interactive weight step (#67/#128): one authority
/// for the stack's `resize("y")` and both track resize knobs, so
/// the step/cap/clamp math cannot drift across the three sites.
@Suite("Weight step authority (#67/#128)")
struct WeightStepTests {
    private let span = 1000.0
    private let minSize = 100.0

    @Test("A positive delta grows the target, others unchanged")
    func growsTarget() {
        let out = StackLayout.weightStep(
            weights: [1, 1, 1],
            at: 0,
            delta: 100,
            span: span,
            minSize: minSize
        )
        #expect(out > 1)
    }

    @Test("Growth caps where the smallest other hits min size")
    func capsAtCliff() {
        // Two windows, 1000 pt span, 100 pt min: the other
        // share can shrink to 100 pt = weight 1 out of a total
        // capped near 10. A huge delta cannot push past that.
        let out = StackLayout.weightStep(
            weights: [1, 1],
            at: 0,
            delta: 100_000,
            span: span,
            minSize: minSize
        )
        // Other window keeps ≥ min: focused/other ratio ≤ 9.
        #expect(out <= 9.0001)
    }

    @Test("The result clamps to the weight range")
    func clampsRange() {
        let big = StackLayout.weightStep(
            weights: [1, 1],
            at: 0,
            delta: 100_000,
            span: 10,
            minSize: 0
        )
        #expect(big <= StackLayout.weightRange.upperBound)
        let small = StackLayout.weightStep(
            weights: [5, 1],
            at: 0,
            delta: -100_000,
            span: 10,
            minSize: 0
        )
        #expect(small >= StackLayout.weightRange.lowerBound)
    }

    @Test("Shrinking is never blocked by the grow cap")
    func shrinkNeverCapped() {
        // Already overflowed (total far above the cliff): a
        // shrink still moves down.
        let out = StackLayout.weightStep(
            weights: [8, 8],
            at: 0,
            delta: -50,
            span: span,
            minSize: minSize
        )
        #expect(out < 8)
    }
}
