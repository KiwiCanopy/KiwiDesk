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
}
