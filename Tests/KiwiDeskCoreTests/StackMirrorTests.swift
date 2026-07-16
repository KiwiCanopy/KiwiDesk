import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w4 = WindowID(4)

private func makeContext() -> LayoutContext {
    LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        gaps: .uniform(10),
        minWindowSize: 100
    )
}

/// #313: the master zone fills from the stack seam when the
/// stack leads and the master lineup is parallel to the split
/// axis, so boundary crossings (minimize-promotion,
/// promote/demote) stay local instead of teleporting across
/// the zone.
@Suite("Stack master-zone seam mirror (#313)")
struct StackMirrorTests {
    private let layout = StackLayout()

    @Test("predicate: leading + parallel mirrors, others don't")
    func predicateMatrix() {
        func params(
            _ position: StackParams.StackPosition,
            _ orientation: StackParams.Orientation
        ) -> StackParams {
            var p = StackParams()
            p.stackPosition = position
            p.masterOrientation = orientation
            return p
        }
        // Leading stack + parallel lineup → mirrored.
        #expect(
            StackLayout.mirrorsMasterZone(
                params(.left, .horizontal)
            )
        )
        #expect(
            StackLayout.mirrorsMasterZone(
                params(.top, .vertical)
            )
        )
        // Perpendicular lineups: every master already touches
        // the seam; array order keeps its natural reading.
        #expect(
            !StackLayout.mirrorsMasterZone(
                params(.left, .vertical)
            )
        )
        #expect(
            !StackLayout.mirrorsMasterZone(
                params(.top, .horizontal)
            )
        )
        // Trailing stack: the boundary master already sits at
        // the seam (the zone's max edge).
        #expect(
            !StackLayout.mirrorsMasterZone(
                params(.right, .horizontal)
            )
        )
        #expect(
            !StackLayout.mirrorsMasterZone(
                params(.bottom, .vertical)
            )
        )
    }

    @Test("left stack: the boundary master sits at the seam")
    func leftStackMirrors() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        context.stack.stackPosition = .left
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let m1 = try #require(frames[w1])
        let m2 = try #require(frames[w2])
        let s = try #require(frames[w3])
        // Stack occupies the leading (left) region.
        #expect(s.minX < m1.minX)
        #expect(s.minX < m2.minX)
        // The boundary master (last master, w2) renders at the
        // stack seam — left of its zone — not the far edge.
        #expect(m2.minX < m1.minX)
        #expect(m2.minY == m1.minY)
    }

    @Test("top stack: the boundary master sits at the seam")
    func topStackMirrors() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        context.stack.stackPosition = .top
        context.stack.masterOrientation = .vertical
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let m1 = try #require(frames[w1])
        let m2 = try #require(frames[w2])
        let s = try #require(frames[w3])
        #expect(s.minY < m1.minY)
        #expect(s.minY < m2.minY)
        #expect(m2.minY < m1.minY)
        #expect(m2.minX == m1.minX)
    }

    @Test("right stack stays unmirrored (seam already adjacent)")
    func rightStackUnmirrored() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let m1 = try #require(frames[w1])
        let m2 = try #require(frames[w2])
        let s = try #require(frames[w3])
        // Array order from the min edge: the boundary master
        // (w2) ends up beside the right stack naturally.
        #expect(m1.minX < m2.minX)
        #expect(m2.maxX < s.minX)
    }

    @Test("perpendicular lineup keeps its natural reading")
    func perpendicularUnmirrored() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        context.stack.stackPosition = .left
        context.stack.masterOrientation = .vertical
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let m1 = try #require(frames[w1])
        let m2 = try #require(frames[w2])
        // Column reads top to bottom in array order; both
        // masters touch the seam already.
        #expect(m1.minY < m2.minY)
        #expect(m1.minX == m2.minX)
    }

    @Test("promotion lands beside the stack, not across the zone")
    func promotionStaysLocal() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        context.stack.stackPosition = .left
        // Before: masters [w1, w2], stack [w3, w4]. The first
        // master closes; w3 slides to the boundary index.
        let after = layout.calculateGeometry(
            for: [w2, w3, w4],
            in: context
        )
        let promoted = try #require(after[w3])
        let survivor = try #require(after[w2])
        let stackWin = try #require(after[w4])
        // The promoted window crosses the seam locally — it is
        // the master nearest the stack it just left.
        #expect(promoted.minX < survivor.minX)
        #expect(stackWin.maxX < promoted.minX)
    }

    @Test("closing the last stack window keeps the master order")
    func masterOnlyConsistency() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        context.stack.stackPosition = .left
        let with = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let without = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        // Relative order survives the stack emptying: the
        // boundary master stays the leading one, so nothing
        // swaps sides when the split collapses.
        let m1With = try #require(with[w1])
        let m2With = try #require(with[w2])
        let m1Without = try #require(without[w1])
        let m2Without = try #require(without[w2])
        #expect(m2With.minX < m1With.minX)
        #expect(m2Without.minX < m1Without.minX)
    }
}
