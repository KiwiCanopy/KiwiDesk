import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #2985: a scrolling restore raises only the windows that show, and
/// waits for the focus raise before its first. Pure geometry and the
/// fake WindowServer, so nothing here reads the host's screen.
@Suite("Scrolling restore raises what shows (#2985)")
struct ZOrderScrollingRestoreTests {
    private let usable = CGRect(x: 0, y: 0, width: 1440, height: 800)
    private let left = CGRect(x: 0, y: 0, width: 700, height: 800)
    private let right = CGRect(x: 740, y: 0, width: 700, height: 800)
    private let sliver = CGRect(
        x: ScrollingLayout.edgePeek - 700,
        y: 0,
        width: 700,
        height: 800
    )

    private func ids(_ raw: [UInt32]) -> [WindowID] {
        raw.map { WindowID($0) }
    }

    private func frames(
        _ placed: [(UInt32, CGRect)]
    ) -> [WindowID: CGRect] {
        Dictionary(
            uniqueKeysWithValues: placed.map { (WindowID($0.0), $0.1) }
        )
    }

    private func plan(
        _ placed: [(UInt32, CGRect)],
        focus: Int
    ) -> (raise: [WindowID], floor: [WindowID], shown: [WindowID]) {
        KiwiCore.scrollingRestorePlan(
            ids(placed.map(\.0)),
            focusIndex: focus,
            frames: frames(placed),
            on: usable
        )
    }

    /// Kiryph's picture: the wrap to the last window walls every
    /// other one at the left, and only the nearest shows there.
    @Test("A wrap to the end raises the pile's top")
    func wrapToEnd() {
        let result = plan(
            [(1, left), (2, left), (3, left), (4, right)],
            focus: 3
        )
        expectEqual(result.raise, ids([3]))
        expectEqual(result.floor, ids([1, 2]))
    }

    /// The owner's picture: the wrap to the first window, whose
    /// neighbour must stand over everything piled at the right.
    @Test("A wrap to the start raises the right pile's top")
    func wrapToStart() {
        let result = plan(
            [(1, left), (2, right), (3, right), (4, right), (5, right)],
            focus: 0
        )
        expectEqual(result.raise, ids([2]))
        expectEqual(result.floor, ids([5, 4, 3]))
    }

    @Test("Focus mid-row raises each side's top, in raise order")
    func midRow() {
        let middle = CGRect(x: 400, y: 0, width: 640, height: 800)
        let result = plan(
            [(1, left), (2, left), (3, middle), (4, right), (5, right)],
            focus: 2
        )
        expectEqual(result.raise, ids([2, 4]))
        expectEqual(result.floor, ids([1, 5]))
    }

    /// A buried window wider than the pile's top shows past it, so
    /// "the top of each pile" alone would leave it stacked anyhow.
    /// A strip this narrow is one the App Bar's verdict reads hidden.
    @Test("A wider buried window pokes out and is raised")
    func widerBuriedWindow() {
        let wide = CGRect(x: 0, y: 0, width: 720, height: 800)
        let result = plan(
            [(1, wide), (2, left), (3, right)],
            focus: 2
        )
        expectEqual(result.raise, ids([1, 2]))
        #expect(result.floor.isEmpty)
    }

    @Test("A row that fits raises nothing and has no floor")
    func fittingRow() {
        let result = plan([(1, left), (2, right)], focus: 0)
        #expect(result.raise.isEmpty)
        #expect(result.floor.isEmpty)
    }

    /// Only the nearest of a sliver pile has anything to show, and
    /// it is too little to arm a step for.
    @Test("The nearest sliver is raised, and arms nothing")
    func nearestSliverIsRaised() {
        let neighbour = CGRect(x: 84, y: 0, width: 700, height: 800)
        let result = plan(
            [(1, sliver), (2, sliver), (3, neighbour)],
            focus: 2
        )
        expectEqual(result.raise, ids([2]))
        expectEqual(result.floor, ids([1]))
        #expect(result.shown.isEmpty)
    }

    /// A flush neighbour covers all a sliver would show.
    @Test("A flush neighbour buries the slivers behind it")
    func flushNeighbourBuries() {
        let result = plan(
            [(1, sliver), (2, sliver), (3, left), (4, right)],
            focus: 3
        )
        expectEqual(result.raise, ids([3]))
        expectEqual(result.floor, ids([1, 2]))
    }

    @Test("A window off the area is buried")
    func offAreaIsBuried() {
        let off = CGRect(x: -800, y: 0, width: 700, height: 800)
        let result = plan([(1, off), (2, left), (3, right)], focus: 2)
        #expect(result.raise.isEmpty)
        expectEqual(result.floor, ids([1]))
    }

    @Test("The focus is never raised nor in the floor")
    func focusStaysOut() {
        let result = plan([(1, left), (2, left), (3, left)], focus: 1)
        #expect(!result.raise.contains(WindowID(2)))
        #expect(!result.floor.contains(WindowID(2)))
    }

    // MARK: - What a step or a close arms for

    @Test("A window showing more than a strip is shown")
    func shownNames() {
        let result = plan(
            [(1, left), (2, left), (3, right)],
            focus: 2
        )
        expectEqual(result.shown, ids([2]))
    }

    /// The row's far strip on a 48% slot: cut by the screen with a
    /// little more than a sliver left, which stands on most steps.
    @Test("A strip the screen cuts is raised but not shown")
    func cutStripIsNotShown() {
        let strip = CGRect(x: -620, y: 0, width: 700, height: 800)
        let neighbour = CGRect(x: 100, y: 0, width: 700, height: 800)
        let result = plan(
            [(1, sliver), (2, strip), (3, neighbour)],
            focus: 2
        )
        expectEqual(result.raise, ids([2]))
        #expect(result.shown.isEmpty)
    }

    /// A buried window a strip of which shows past the pile's top.
    @Test("A strip past a cover is raised but not shown")
    func coveredStripIsNotShown() {
        let wide = CGRect(x: 0, y: 0, width: 720, height: 800)
        let result = plan([(1, wide), (2, left), (3, right)], focus: 2)
        expectEqual(result.raise, ids([1, 2]))
        expectEqual(result.shown, ids([2]))
    }

    // MARK: - The drain's wait on the focus

    /// The old key window stands over a raise until the activation
    /// lands, so the first raise waits for the focus to clear it.
    @Test("The first raise waits for the focus to clear the floor")
    func waitsForTheFocus() {
        let server = FakeWindowServer(order: ids([1, 3, 4]))
        server.land(WindowID(4), after: 0.03)
        let drain = server.restoreDrain(
            above: ids([1]),
            front: WindowID(4)
        )
        _ = drain.run(ids([3]))
        expectEqual(server.raised, ids([3]))
        expectEqual(server.raisedAt.first.map { $0 >= 0.03 }, true)
        expectEqual(server.stacking(), ids([3, 4, 1]))
    }

    @Test("A focus that never lands costs one landing limit")
    func waitIsBounded() {
        let server = FakeWindowServer(order: ids([1, 3, 4]))
        let drain = server.restoreDrain(
            above: ids([1]),
            front: WindowID(4)
        )
        _ = drain.run(ids([3]))
        let at = server.raisedAt.first ?? .infinity
        #expect(at >= ZOrderDrain.landingLimit)
        #expect(
            at <= ZOrderDrain.landingLimit + ZOrderDrain.pollInterval
        )
    }

    @Test("A focus already above the floor raises at once")
    func noWaitWhenSettled() {
        let server = FakeWindowServer(order: ids([4, 1, 3]))
        let drain = server.restoreDrain(
            above: ids([1]),
            front: WindowID(4)
        )
        _ = drain.run(ids([3]))
        expectEqual(server.raisedAt, [0])
    }

    @Test("A superseded drain stops waiting")
    func supersededStopsWaiting() {
        let server = FakeWindowServer(order: ids([1, 3, 4]))
        // Current at the drain's opening guard, stale within the wait.
        server.currentUntilClock = 0.03
        let drain = server.restoreDrain(
            above: ids([1]),
            front: WindowID(4)
        )
        _ = drain.run(ids([3]))
        #expect(server.raised.isEmpty)
        #expect(server.clock < ZOrderDrain.landingLimit)
    }

    @Test("A drain that names no focus does not wait")
    func noFrontNoWait() {
        let server = FakeWindowServer(order: ids([1, 3, 4]))
        _ = server.restoreDrain(above: ids([1])).run(ids([3]))
        expectEqual(server.raisedAt, [0])
    }
}
