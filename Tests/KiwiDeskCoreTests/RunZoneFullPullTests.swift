import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A press that lets every member of a run fit (#2709): no run is
/// left to hold a length, so the window keeps it as the weight that
/// draws it there. Pure, reading the frames the render draws.
@Suite("Run zone full pull (#2709)")
struct RunZoneFullPullTests {
    private let ids = (1...4).map { WindowID(UInt32($0)) }

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

    /// `press` written into `context`, as the writers store it.
    private func written(
        _ press: RunZone.Press,
        of id: WindowID,
        over context: LayoutContext,
        in zone: RunZone
    ) -> LayoutContext {
        var after = context
        for (member, share) in press.sizes {
            after.runSizes[member] = share.map {
                RunSize(share: $0, zone: 0)
            }
        }
        if let weight = press.weight { after.stackWeights[id] = weight }
        if let visible = press.visible {
            (after.runHeads, after.runTails) = zone.ends(
                showing: visible,
                heads: after.runHeads,
                tails: after.runTails
            )
        }
        return after
    }

    private func two() -> RunZone {
        RunZone(
            members: Array(ids[0..<2]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
    }

    @Test("A pull showing every member draws the next at its minimum")
    func fullPullKeepsTheLength() throws {
        let zone = two()
        let lone = context(focus: 1, sizes: [1: 1000], tails: [1])
        let press = try #require(
            zone.press(ids[0], by: -1, toward: .end, in: lone)
        )
        #expect(press.sizes[ids[0]] == .some(nil))
        let after = written(press, of: ids[0], over: lone, in: zone)
        #expect(zone.run(in: after) == nil)
        let next = try #require(zone.frames(in: after)[ids[1]])
        #expect(abs(next.width - 300) < 1)
    }

    @Test("A full pull counts the others' stored weights")
    func fullPullCountsWeights() throws {
        let zone = two()
        var lone = context(focus: 1, sizes: [1: 1000], tails: [1])
        lone.stackWeights[ids[1]] = 2.33
        let press = try #require(
            zone.press(ids[0], by: -1, toward: .end, in: lone)
        )
        let after = written(press, of: ids[0], over: lone, in: zone)
        let next = try #require(zone.frames(in: after)[ids[1]])
        #expect(abs(next.width - 300) < 1)
    }

    @Test("A full pull over unequal floors lands where it was asked")
    func fullPullOverUnequalFloors() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        var sized = context(sizes: [1: 500], tails: [2])
        sized.minWindowSize = 100
        sized.sizeBounds[ids[2]] = EffectiveSizeBound(width: [
            .init(asked: 50, answered: 500)
        ])
        let press = try #require(
            three.press(ids[0], by: -250, toward: .end, in: sized)
        )
        expectEqual(press.visible, 0..<3)
        let after = written(press, of: ids[0], over: sized, in: three)
        let frame = try #require(three.frames(in: after)[ids[0]])
        #expect(abs(frame.width - 250) < 1)
    }

    @Test("A full pull down to a window's floor comes near it")
    func fullPullToTheFloor() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        var sized = context(sizes: [1: 500], tails: [2])
        sized.minWindowSize = 100
        sized.sizeBounds[ids[2]] = EffectiveSizeBound(width: [
            .init(asked: 50, answered: 500)
        ])
        let press = try #require(
            three.press(ids[0], by: -400, toward: .end, in: sized)
        )
        expectEqual(press.visible, 0..<3)
        let after = written(press, of: ids[0], over: sized, in: three)
        let frame = try #require(three.frames(in: after)[ids[0]])
        #expect(abs(frame.width - 100) < 15)
    }

    @Test("A shrink that lets every member fit keeps its length as a weight")
    func shrinkToFitEveryone() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        let sized = context(sizes: [2: 600], tails: [2])
        expectEqual(three.run(in: sized)?.visible, 0..<2)
        let press = try #require(
            three.press(ids[1], by: -250, toward: .end, in: sized)
        )
        expectEqual(press.visible, 0..<3)
        #expect(press.sizes[ids[1]] == .some(nil))
        let after = written(press, of: ids[1], over: sized, in: three)
        let frame = try #require(three.frames(in: after)[ids[1]])
        #expect(abs(frame.width - 350) < 1)
    }
}
