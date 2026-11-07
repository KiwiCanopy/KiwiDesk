import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The one rule every scrolling layout's resize along its run takes
/// (#2709): a grow past what the shown neighbours can give pushes
/// the one on the moved side into the run, a shrink pulls the
/// waiting one past the moved edge back while it fits. Pure, over
/// one horizontal zone of four 300-pt floors in 1000 pt, with
/// `Gaps()`' inner gap;
/// a run size is a share of that span.
@Suite("Run zone push (#2709)")
struct RunZonePushTests {
    private let ids = (1...4).map { WindowID(UInt32($0)) }

    private var zone: RunZone {
        RunZone(
            members: ids,
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
    }

    private func context(
        focus: Int = 2,
        sizes: [Int: CGFloat] = [:],
        heads: Set<Int> = [],
        tails: Set<Int> = []
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 600),
            focused: WindowID(UInt32(focus)),
            minWindowSize: 300,
            runHeads: Set(heads.map { WindowID(UInt32($0)) }),
            runTails: Set(tails.map { WindowID(UInt32($0)) })
        )
        for (id, size) in sizes {
            context.runSizes[WindowID(UInt32(id))] = RunSize(
                share: size / 1000,
                zone: 0
            )
        }
        return context
    }

    /// `context` with `press` written as the writers write it.
    private func writing(
        _ press: RunZone.Press,
        over context: LayoutContext
    ) -> LayoutContext {
        var context = context
        for (member, share) in press.sizes {
            context.runSizes[member] = share.map {
                RunSize(share: $0, zone: 0)
            }
        }
        if let visible = press.visible {
            (context.runHeads, context.runTails) = zone.ends(
                showing: visible,
                heads: context.runHeads,
                tails: context.runTails
            )
        }
        return context
    }

    /// The share `press` gives window `id`, 0 where it sets none.
    private func size(_ press: RunZone.Press, _ id: Int) -> CGFloat {
        (press.sizes[WindowID(UInt32(id))] ?? nil) ?? 0
    }

    @Test("At rest the run shows the first three and hides the fourth")
    func restingRun() {
        expectEqual(zone.run(in: context())?.visible, 0..<3)
    }

    @Test("A grow toward the end pushes the end neighbour")
    func growPushesTheEnd() throws {
        let rest = try #require(zone.frames(in: context())[ids[0]])
        let press = try #require(
            zone.press(ids[1], by: 200, toward: .end, in: context())
        )
        expectEqual(press.visible, 0..<2)
        #expect(press.movesRun)
        let after = writing(press, over: context())
        expectEqual(zone.run(in: after)?.visible, 0..<2)
        let frame = try #require(zone.frames(in: after)[ids[1]])
        #expect(abs(frame.width - size(press, 2) * 1000) < 0.5)
        // Window 2 takes window 3's room: window 1 keeps what it
        // drew.
        let kept = try #require(zone.frames(in: after)[ids[0]])
        #expect(abs(kept.width - rest.width) < 0.5)
        #expect(abs(frame.minX - kept.maxX) < 50)
        #expect(abs(frame.maxX - 1000) < 0.5)
    }

    @Test("A grow toward the start pushes the start neighbour")
    func growPushesTheStart() throws {
        let press = try #require(
            zone.press(ids[1], by: 200, toward: .start, in: context())
        )
        expectEqual(press.visible, 1..<3)
        let after = writing(press, over: context())
        expectEqual(zone.run(in: after)?.visible, 1..<3)
    }

    @Test("A grow squeezing both sides sends the last in order")
    func growBothSendsTheLast() throws {
        let press = try #require(
            zone.press(ids[1], by: 200, toward: .both, in: context())
        )
        expectEqual(press.visible, 0..<2)
    }

    @Test("A grow the neighbours can still give is the weight step")
    func smallGrowKeepsTheRun() throws {
        let press = try #require(
            zone.press(ids[1], by: 20, toward: .end, in: context())
        )
        #expect(press.visible == nil)
        #expect(press.sizes.isEmpty)
        #expect((press.weight ?? 1) > 1)
    }

    /// Window 2 grown to 600 with 3 shown beside it: windows 1 and
    /// 4 wait at the two ends, and a shrink to 300 frees room for
    /// exactly one of them.
    private func middle() -> LayoutContext {
        context(sizes: [2: 600], heads: [2], tails: [3])
    }

    @Test("A middle run hides one window at each end")
    func middleRun() {
        expectEqual(zone.run(in: middle())?.visible, 1..<3)
    }

    /// Window 2 alone in the run, filling the zone, with window 1
    /// waiting before it and windows 3 and 4 after it.
    private func lone() -> LayoutContext {
        context(sizes: [2: 1000], heads: [2], tails: [2])
    }

    @Test("A lone window's shrink pulls back the one past the moved edge")
    func shrinkPullsTheMovedSide() throws {
        expectEqual(zone.run(in: lone())?.visible, 1..<2)
        let start = try #require(
            zone.press(ids[1], by: -1, toward: .start, in: lone())
        )
        expectEqual(start.visible, 0..<2)
        let end = try #require(
            zone.press(ids[1], by: -1, toward: .end, in: lone())
        )
        expectEqual(end.visible, 1..<3)
        let both = try #require(
            zone.press(ids[1], by: -1, toward: .both, in: lone())
        )
        expectEqual(both.visible, 1..<3)
        let after = writing(start, over: lone())
        expectEqual(zone.run(in: after)?.visible, 0..<2)
    }

    @Test("With nothing waiting past its edge a lone shrink pulls the other")
    func shrinkFallsBackToTheOtherEnd() throws {
        let head = context(focus: 1, sizes: [1: 1000], tails: [1])
        let first = try #require(
            zone.press(ids[0], by: -1, toward: .start, in: head)
        )
        expectEqual(first.visible, 0..<2)
        let tail = context(focus: 4, sizes: [4: 1000], heads: [4])
        let last = try #require(
            zone.press(ids[3], by: -1, toward: .end, in: tail)
        )
        expectEqual(last.visible, 2..<4)
    }

    @Test("A lone pull stops at a window that does not fit, never skipping")
    func pullStopsAtTheFirstMisfit() throws {
        // Window 1 waits with a learned 800-pt floor: it cannot fit
        // beside window 2, and window 3 is not taken in its place.
        var held = lone()
        held.sizeBounds[ids[0]] = EffectiveSizeBound(width: [
            .init(asked: 50, answered: 800)
        ])
        let press = try #require(
            zone.press(ids[1], by: -1, toward: .start, in: held)
        )
        #expect(!press.movesRun)
        #expect(press.visible == nil)
        #expect(press.sizes.isEmpty)
    }

    @Test("A pull judges a waiting window at its floor, not its length")
    func pullJudgesTheFloor() throws {
        // Window 1 waits holding 800: at its 300 floor it fits, and
        // it comes back with no length of its own.
        let held = context(sizes: [1: 800, 2: 1000], heads: [2], tails: [2])
        let press = try #require(
            zone.press(ids[1], by: -1, toward: .start, in: held)
        )
        expectEqual(press.visible, 0..<2)
        #expect(press.sizes[ids[0]] == .some(nil))
    }

    @Test("A shrink beside a shown mate pulls nothing, even with room")
    func shrinkBesideAMatePullsNothing() throws {
        // Window 2 shrinks to its floor: window 1 or 4 would fit, and
        // window 3 takes the room instead.
        let press = try #require(
            zone.press(ids[1], by: -300, toward: .end, in: middle())
        )
        expectEqual(press.visible, 1..<3)
        #expect(!press.movesRun)
        #expect(abs(size(press, 2) - 0.3) < 1e-9)
    }

    @Test("Growing to alone and any shrink bring back the same window")
    func roundTrip() throws {
        let rest = context(focus: 1)
        let grown = try #require(
            zone.press(ids[0], by: 900, toward: .both, in: rest)
        )
        expectEqual(grown.visible, 0..<1)
        let shrunk = try #require(
            zone.press(
                ids[0],
                by: -1,
                toward: .both,
                in: writing(grown, over: rest)
            )
        )
        expectEqual(shrunk.visible, 0..<2)
    }

    @Test("A grow squeezes the window taking the rest before it pushes")
    func growSqueezesTheTaker() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        // Both hold a length, so window 2 takes the rest: it gives
        // back down to its floor before anything leaves.
        let sized = context(focus: 1, sizes: [1: 400, 2: 500], tails: [2])
        let press = try #require(
            three.press(ids[0], by: 100, toward: .end, in: sized)
        )
        expectEqual(press.visible, 0..<2)
        #expect(!press.movesRun)
    }

    @Test("A window holding no length never pulls, even with room")
    func unsizedShrinkPullsNothing() throws {
        // The run rests pinned at two windows where three would fit:
        // window 2's shrink hands its room to window 1 instead.
        let pinned = context(tails: [2])
        expectEqual(zone.run(in: pinned)?.visible, 0..<2)
        let press = try #require(
            zone.press(ids[1], by: -150, toward: .end, in: pinned)
        )
        #expect(press.visible == nil)
        #expect(press.weight != nil)
        #expect(!press.movesRun)
    }

    @Test("A shrink past the window's floor stops there and says so")
    func shrinkAtOwnFloor() throws {
        let press = try #require(
            zone.press(ids[1], by: -400, toward: .end, in: middle())
        )
        expectEqual(press.cue, .ownMinimum)
        #expect(abs(size(press, 2) - 0.3) < 1e-9)
    }

    @Test("A window not shown has nothing to resize")
    func hiddenWindowAnswersNil() {
        #expect(
            zone.press(ids[3], by: 50, toward: .end, in: context()) == nil
        )
    }
}
