import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)

/// Monocle's consumption of a confirmed app bound (#677, owner
/// ruling): the refused window takes the learned answer
/// CENTERED in the slot — residue split symmetrically instead
/// of piling on one side — while every unbounded window keeps
/// the full frame. Display pinned via the context bounds
/// (#531).
@Suite("Monocle bound centering (#677)")
struct MonocleBoundCenterTests {
    let layout = MonocleLayout()

    private func makeContext() -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            ),
            gaps: .uniform(10)
        )
        context.monocle.appBar.enabled = false
        return context
    }

    @Test("A refused window centers; siblings keep the frame")
    func refusedWindowCenters() throws {
        var context = makeContext()
        let area = context.usable
        context.sizeBounds[w1] = EffectiveSizeBound(
            width: .init(asked: area.width, answered: 715),
            height: .init(asked: area.height, answered: 600)
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let bounded = try #require(frames[w1])
        #expect(bounded.size == CGSize(width: 715, height: 600))
        #expect(abs(bounded.midX - area.midX) < 0.01)
        #expect(abs(bounded.midY - area.midY) < 0.01)
        #expect(frames[w2] == area)
    }

    @Test("One consumed axis centers alone")
    func singleAxisCenters() throws {
        var context = makeContext()
        let area = context.usable
        context.sizeBounds[w1] = EffectiveSizeBound(
            width: .init(asked: area.width, answered: 715)
        )
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        let bounded = try #require(frames[w1])
        #expect(bounded.width == 715)
        #expect(abs(bounded.midX - area.midX) < 0.01)
        // The unbounded axis keeps the full extent and origin.
        #expect(bounded.height == area.height)
        #expect(bounded.minY == area.minY)
    }

    @Test("An unmatched ask keeps the full frame")
    func unmatchedAskKeepsFrame() throws {
        // Learned against some other slot (a display change
        // moved the monocle area): the new ask must be probed.
        var context = makeContext()
        context.sizeBounds[w1] = EffectiveSizeBound(
            width: .init(asked: 900, answered: 715)
        )
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }
}
