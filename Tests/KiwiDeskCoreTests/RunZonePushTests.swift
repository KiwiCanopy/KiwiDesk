import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The one rule every scrolling layout's resize along its run takes
/// (#2709): a grow past what the shown neighbours can give pushes
/// the one on the moved side into the run, a shrink pulls the
/// waiting one past the moved edge back while it fits. Pure, over
/// one horizontal zone of four 300-pt floors in 1000 pt, no gaps;
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
        #expect(zone.run(in: context())?.visible == 0..<3)
    }

    @Test("A grow toward the end pushes the end neighbour")
    func growPushesTheEnd() throws {
        let rest = try #require(zone.frames(in: context())[ids[0]])
        let press = try #require(
            zone.press(ids[1], by: 200, toward: .end, in: context())
        )
        #expect(press.visible == 0..<2)
        #expect(press.movesRun)
        let after = writing(press, over: context())
        #expect(zone.run(in: after)?.visible == 0..<2)
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
        #expect(press.visible == 1..<3)
        let after = writing(press, over: context())
        #expect(zone.run(in: after)?.visible == 1..<3)
    }

    @Test("A grow squeezing both sides sends the last in order")
    func growBothSendsTheLast() throws {
        let press = try #require(
            zone.press(ids[1], by: 200, toward: .both, in: context())
        )
        #expect(press.visible == 0..<2)
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
        #expect(zone.run(in: middle())?.visible == 1..<3)
    }

    @Test("A shrink pulls back the window past the moved edge")
    func shrinkPullsTheMovedSide() throws {
        let start = try #require(
            zone.press(ids[1], by: -300, toward: .start, in: middle())
        )
        #expect(start.visible == 0..<3)
        let end = try #require(
            zone.press(ids[1], by: -300, toward: .end, in: middle())
        )
        #expect(end.visible == 1..<4)
        let both = try #require(
            zone.press(ids[1], by: -300, toward: .both, in: middle())
        )
        #expect(both.visible == 1..<4)
        let after = writing(start, over: middle())
        #expect(zone.run(in: after)?.visible == 0..<3)
    }

    @Test("A shrink with nothing waiting past its edge pulls the other end")
    func shrinkFallsBackToTheOtherEnd() throws {
        // Window 2 grown at the head: only window 4 waits, past
        // the end, and a shrink of the start edge still brings it.
        let grown = context(sizes: [2: 600], tails: [3])
        let press = try #require(
            zone.press(ids[1], by: -300, toward: .start, in: grown)
        )
        #expect(press.visible == 0..<3)
        // Window 3 grown at the tail end: windows 1 and 2 wait
        // before it, and a shrink of its end edge brings window 2.
        let tail = context(focus: 3, sizes: [3: 600], heads: [3])
        #expect(zone.run(in: tail)?.visible == 2..<4)
        let pulled = try #require(
            zone.press(ids[2], by: -300, toward: .end, in: tail)
        )
        #expect(pulled.visible == 1..<4)
    }

    @Test("A pull stops at a window that does not fit, never skipping it")
    func pullStopsAtTheFirstMisfit() throws {
        // Window 1 waits before the run with a learned 500-pt floor,
        // window 4 after it at 300: a shrink of window 2's start
        // edge frees room for 300 alone, so nothing comes back.
        var held = context(sizes: [2: 600], heads: [2], tails: [3])
        held.sizeBounds[ids[0]] = EffectiveSizeBound(width: [
            .init(asked: 50, answered: 500)
        ])
        #expect(zone.run(in: held)?.visible == 1..<3)
        let press = try #require(
            zone.press(ids[1], by: -300, toward: .start, in: held)
        )
        #expect(press.visible == 1..<3)
        #expect(!press.movesRun)
    }

    @Test("A window holding no length never pulls, even with room")
    func unsizedShrinkPullsNothing() throws {
        // The run rests pinned at two windows where three would fit:
        // window 2's shrink hands its room to window 1 instead.
        let pinned = context(tails: [2])
        #expect(zone.run(in: pinned)?.visible == 0..<2)
        let press = try #require(
            zone.press(ids[1], by: -150, toward: .end, in: pinned)
        )
        #expect(press.visible == nil)
        #expect(press.weight != nil)
        #expect(!press.movesRun)
    }

    @Test("A pull judges a waiting window at its floor, not its length")
    func pullJudgesTheFloor() throws {
        // Window 1 waits holding 500: at its 300 floor it fits, and
        // it comes back at its floor and share.
        let held = context(sizes: [1: 500, 2: 600], heads: [2], tails: [3])
        let press = try #require(
            zone.press(ids[1], by: -300, toward: .start, in: held)
        )
        #expect(press.visible == 0..<3)
        #expect(press.sizes[ids[0]] == .some(nil))
    }

    @Test("A shrink that frees too little pulls nothing")
    func shrinkStopsAtTheFloor() throws {
        let press = try #require(
            zone.press(ids[1], by: -50, toward: .end, in: middle())
        )
        #expect(press.visible == 1..<3)
        #expect(press.cue == nil)
    }

    @Test("A shrink past the window's floor stops there and says so")
    func shrinkAtOwnFloor() throws {
        let press = try #require(
            zone.press(ids[1], by: -400, toward: .end, in: middle())
        )
        #expect(press.cue == .ownMinimum)
        #expect(abs(size(press, 2) - 0.3) < 1e-9)
    }

    @Test("A grow and the matching shrink bring back the same window")
    func roundTrip() throws {
        let rest = context()
        let grown = try #require(
            zone.press(ids[1], by: 200, toward: .both, in: rest)
        )
        let pushed = writing(grown, over: rest)
        let extent = try #require(zone.frames(in: pushed)[ids[1]]).width
        let shrunk = try #require(
            zone.press(ids[1], by: 300 - extent, toward: .both, in: pushed)
        )
        #expect(shrunk.visible == 0..<3)
    }

    @Test("A window not shown has nothing to resize")
    func hiddenWindowAnswersNil() {
        #expect(
            zone.press(ids[3], by: 50, toward: .end, in: context()) == nil
        )
    }
}
