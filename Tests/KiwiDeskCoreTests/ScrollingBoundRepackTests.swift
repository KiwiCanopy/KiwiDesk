import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// Scrolling's consumption of a confirmed app bound (#677,
/// owner ruling): the refused slot takes the answered span and
/// the row RE-PACKS, so neighbors close the reserved-slot gap
/// (and pack apart in the mirror case). Only the refused ask
/// consumes; a lone window centers instead, having no neighbors
/// to re-pack against. Display pinned via the context bounds
/// (#531); the app bar is off to isolate the column mechanics,
/// as `ScrollingLayoutTests` does.
@Suite("Scrolling bound re-pack (#677)")
struct ScrollingBoundRepackTests {
    let layout = ScrollingLayout()

    private func makeContext(
        focused: WindowID? = nil
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            ),
            gaps: .uniform(10),
            focused: focused
        )
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(600)
        return context
    }

    @Test("Neighbors close a refused slot's gap")
    func repackClosesGap() throws {
        var context = makeContext()
        context.sizeBounds[w2] = EffectiveSizeBound(
            width: .init(asked: 600, answered: 400)
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let area = context.usable
        let first = try #require(frames[w1])
        let bounded = try #require(frames[w2])
        let third = try #require(frames[w3])
        #expect(first.minX == area.minX)
        #expect(first.width == 600)
        #expect(bounded.minX == area.minX + 610)
        #expect(bounded.width == 400)
        // The whole point: w3 packs against the ANSWERED span,
        // not the reserved 600 pt slot (which would put it at
        // minX + 1220 and leave a 200 pt hole).
        #expect(third.minX == area.minX + 1020)
        #expect(third.width == 600)
    }

    @Test("The mirror case packs apart instead of overlapping")
    func floorPacksApart() throws {
        // Slot narrower than the app's minimum (#677's mirror):
        // the answered span is WIDER, and the neighbor moves
        // out instead of being overlapped.
        var context = makeContext()
        context.sizeBounds[w1] = EffectiveSizeBound(
            width: .init(asked: 600, answered: 800)
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let area = context.usable
        let bounded = try #require(frames[w1])
        let second = try #require(frames[w2])
        #expect(bounded.width == 800)
        #expect(second.minX == area.minX + 810)
    }

    @Test("An unmatched ask does not consume")
    func unmatchedAskDoesNotConsume() throws {
        // The bound was learned against a 700 pt ask; the slot
        // now asks 600, which the app has never refused — the
        // layout must probe it, not swap in a stale answer.
        var context = makeContext()
        context.sizeBounds[w2] = EffectiveSizeBound(
            width: .init(asked: 700, answered: 400)
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        #expect(try #require(frames[w2]).width == 600)
        #expect(
            try #require(frames[w3]).minX
                == context.usable.minX + 1220
        )
    }

    @Test("The center anchor rests on the answered span")
    func centerAnchorUsesAnsweredSpan() throws {
        var context = makeContext(focused: w2)
        context.scrolling.anchor = .center
        // A slot wide enough that the row overflows the
        // viewport — a row that fits entirely clamps its
        // offset to 0 and no anchor can act.
        context.scrolling.slotSize = .points(800)
        context.sizeBounds[w2] = EffectiveSizeBound(
            width: .init(asked: 800, answered: 400)
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let focused = try #require(frames[w2])
        #expect(focused.width == 400)
        // Centered by its OWN span — the reserved ask would
        // rest it 100 pt off center.
        #expect(
            abs(focused.midX - context.usable.midX) < 0.01
        )
    }

    @Test("A vertical row consumes the height axis")
    func verticalRowConsumesHeight() throws {
        var context = makeContext()
        context.scrolling.orientation = .vertical
        context.sizeBounds[w1] = EffectiveSizeBound(
            height: .init(asked: 600, answered: 450)
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let area = context.usable
        #expect(try #require(frames[w1]).height == 450)
        #expect(
            try #require(frames[w2]).minY == area.minY + 460
        )
    }

    @Test("A lone refused window centers in the area")
    func loneWindowCenters() throws {
        var context = makeContext()
        let area = context.usable
        context.sizeBounds[w1] = EffectiveSizeBound(
            width: .init(asked: area.width, answered: 700)
        )
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        let lone = try #require(frames[w1])
        #expect(lone.width == 700)
        #expect(abs(lone.midX - area.midX) < 0.01)
        // The unconsumed axis keeps the full extent.
        #expect(lone.height == area.height)
    }
}
