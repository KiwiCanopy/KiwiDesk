import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Where a push's length plans and how a press answers beside one
/// (#2709): the gate, a lone or last sized window, the nearest mate
/// and the weight step. Pure, over `RunZonePushTests`' zone of four
/// 300-pt floors in 1000 pt.
@Suite("Run zone sizes (#2709)")
struct RunZoneSizesTests {
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

    /// Window 2 sized to 600 with window 3 shown beside it, windows
    /// 1 and 4 waiting at the two ends.
    private func middle() -> LayoutContext {
        context(sizes: [2: 600], heads: [2], tails: [3])
    }

    @Test("A run that would show everything plans no length")
    func fittingRunPlansNoLength() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        let sized = context(sizes: [2: 350], tails: [3])
        #expect(three.sizedMembers(in: sized).isEmpty)
        #expect(zone.sizedMembers(in: middle()) == [ids[1]])
    }

    @Test("A length given in another zone plans nothing here")
    func foreignLengthPlansNothing() {
        var moved = middle()
        moved.runSizes[ids[1]] = RunSize(share: 0.6, zone: 1)
        #expect(zone.sizedMembers(in: moved).isEmpty)
        // Nor without stored ends.
        #expect(zone.sizedMembers(in: context(sizes: [2: 600])).isEmpty)
    }

    @Test("A run showing only sized windows lets its last take the rest")
    func allSizedLastAbsorbs() throws {
        let both = context(sizes: [2: 450, 3: 450], heads: [2], tails: [3])
        #expect(zone.run(in: both)?.visible == 1..<3)
        let frames = zone.frames(in: both)
        let first = try #require(frames[ids[1]])
        let last = try #require(frames[ids[2]])
        #expect(abs(first.width - 450) < 0.5)
        #expect(abs(last.maxX - 1000) < 0.5)
        #expect(zone.shareWeights(in: both)[2] > 0)
    }

    @Test("A sized window before the last draws its length")
    func pulledSizedWindowKeepsBoth() throws {
        // Both hold a length: window 2, shown last, takes the rest,
        // and window 1 draws what it holds.
        let pulled = context(focus: 1, sizes: [1: 450, 2: 500], tails: [2])
        let frame = try #require(zone.frames(in: pulled)[ids[0]])
        #expect(abs(frame.width - 450) < 0.5)
    }

    @Test("A lone window fills its zone whatever length it holds")
    func loneWindowFills() throws {
        let lone = context(focus: 1, sizes: [1: 600], tails: [1])
        #expect(zone.run(in: lone)?.visible == 0..<1)
        let frame = try #require(zone.frames(in: lone)[ids[0]])
        #expect(frame.width == 1000)
    }

    @Test("A lone window's shrink gives up only what the next one needs")
    func loneShrinkSnaps() throws {
        let lone = context(focus: 1, sizes: [1: 1000], tails: [1])
        let press = try #require(
            zone.press(ids[0], by: -1, toward: .end, in: lone)
        )
        #expect(press.visible == 0..<2)
        let share = try #require(press.sizes[ids[0]] ?? nil)
        #expect(share > 0.65)
        #expect(share < 0.7)
    }

    @Test("A larger shrink of a lone window goes where it was asked")
    func loneShrinkTakesTheAsk() throws {
        let lone = context(focus: 1, sizes: [1: 1000], tails: [1])
        let press = try #require(
            zone.press(ids[0], by: -600, toward: .end, in: lone)
        )
        let share = try #require(press.sizes[ids[0]] ?? nil)
        #expect(abs(share - 0.4) < 1e-9)
    }

    @Test("A lone window with no room for the next moves nothing")
    func loneShrinkWithoutRoom() throws {
        var lone = context(focus: 1, sizes: [1: 1000], tails: [1])
        lone.sizeBounds[ids[0]] = EffectiveSizeBound(width: [
            .init(asked: 50, answered: 900)
        ])
        let press = try #require(
            zone.press(ids[0], by: -50, toward: .end, in: lone)
        )
        #expect(!press.movesRun)
        #expect(press.refusal != nil)
        #expect(press.sizes.isEmpty)
    }

    @Test("A neighbour's shrink widens the window taking the rest")
    func neighbourShrinkKeepsThePush() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 900, height: 600),
            vertical: false
        )
        let sized = context(
            focus: 1,
            sizes: [1: 400, 2: 500],
            tails: [2]
        )
        #expect(three.run(in: sized)?.visible == 0..<2)
        let press = try #require(
            three.press(ids[0], by: -50, toward: .end, in: sized)
        )
        #expect(press.visible == 0..<2)
        #expect(!press.movesRun)
    }

    @Test("A lone window short of its floor and of room says nothing divides")
    func loneRefusalIsNotAtItsFloor() throws {
        var lone = context(focus: 1, sizes: [1: 1000], tails: [1])
        lone.sizeBounds[ids[0]] = EffectiveSizeBound(width: [
            .init(asked: 50, answered: 900)
        ])
        let press = try #require(
            zone.press(ids[0], by: -150, toward: .end, in: lone)
        )
        #expect(press.refusal == .alone)
        #expect(press.cue == .nothingToDivide)
    }

    @Test("A zone that piles answers no press")
    func piledZoneAnswersNothing() {
        let piled = RunZone(
            members: ids,
            region: CGRect(x: 0, y: 0, width: 200, height: 600),
            vertical: false
        )
        #expect(piled.piles(in: context()))
        #expect(
            piled.press(ids[1], by: 50, toward: .end, in: context()) == nil
        )
    }

    @Test("A press beside sized mates moves the nearest one's length")
    func nearestMateMoves() throws {
        let before = try #require(
            zone.press(
                ids[2],
                by: 10,
                toward: .start,
                in: context(focus: 3, sizes: [1: 320, 2: 320], tails: [3])
            )
        )
        #expect(before.sizes[ids[1]] != nil)
        #expect(before.sizes[ids[0]] == nil)
        let after = try #require(
            zone.press(
                ids[0],
                by: 10,
                toward: .end,
                in: context(focus: 1, sizes: [2: 320, 3: 320], tails: [3])
            )
        )
        #expect(after.sizes[ids[1]] != nil)
        #expect(after.sizes[ids[2]] == nil)
    }

    @Test("The weight step divides only among windows that take a share")
    func weightStepSkipsASizedMate() throws {
        let sized = context(sizes: [1: 350], tails: [3])
        let extra = try #require(zone.runExtra(in: sized))
        let press = try #require(
            zone.press(ids[1], by: 10, toward: .end, in: sized)
        )
        let expected = StackLayout.weightStep(
            weights: [0, 1, 1],
            at: 1,
            delta: 10,
            span: Double(extra),
            minSizes: [0, 0, 0]
        ).value
        #expect(press.weight == expected)
    }
}
