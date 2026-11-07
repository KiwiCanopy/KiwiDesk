import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A press at a weight's limit, a step under the tolerance and a
/// pull beside a window taking the rest (#2709). Pure, over four
/// 300-pt floors.
@Suite("Run zone press limits (#2709)")
struct RunZonePressLimitTests {
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

    @Test("A shrink that lets all fit at their floors pulls past a taker")
    func shrinkPullsPastATaker() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        // The window taking the rest holds a length, as a press on it
        // leaves one; that length is what it draws, never a floor.
        let sized = context(
            focus: 1,
            sizes: [1: 400, 2: 590],
            tails: [2]
        )
        let press = try #require(
            three.press(ids[0], by: -50, toward: .end, in: sized)
        )
        expectEqual(press.visible, 0..<3)
        #expect(press.movesRun)
    }

    @Test("A pull back of every window cues no minimum")
    func pullAtFloorCuesNothing() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        let sized = context(
            focus: 1,
            sizes: [1: 300, 2: 690],
            tails: [2]
        )
        let press = try #require(
            three.press(ids[0], by: -5, toward: .end, in: sized)
        )
        #expect(press.movesRun)
        #expect(press.cue == nil)
    }

    @Test("A step under the tolerance still moves a sized window")
    func tinyStepMoves() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 900, height: 600),
            vertical: false
        )
        let sized = context(focus: 1, sizes: [1: 400], tails: [2])
        let press = try #require(
            three.press(ids[0], by: 0.3, toward: .end, in: sized)
        )
        #expect(press.refusal == nil)
        #expect(press.cue == nil)
        let share = try #require(press.sizes[ids[0]] ?? nil)
        #expect(share > 400 / 1000)
        // Beside only sized mates, a tiny shrink is no minimum either.
        let beside = context(
            focus: 2,
            sizes: [1: 300, 2: 500],
            tails: [2]
        )
        let small = try #require(
            three.press(ids[1], by: -0.3, toward: .end, in: beside)
        )
        #expect(small.refusal == nil)
        #expect(small.cue == nil)
    }

    @Test("A grow at the weight's limit takes a length, and the mates give")
    func spentGrowTakesALength() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 900, height: 600),
            vertical: false
        )
        var spent = context(focus: 1, tails: [2])
        spent.stackWeights[ids[0]] = StackLayout.weightRange.upperBound
        let drawn = try #require(three.frames(in: spent)[ids[0]]).width
        let press = try #require(
            three.press(ids[0], by: 5, toward: .end, in: spent)
        )
        let share = try #require(press.sizes[ids[0]] ?? nil)
        #expect(abs(share * 900 - (drawn + 5)) < 0.01)
        // The length replaces the weight.
        expectEqual(press.weight, 1)
    }

    @Test("A hold's stop beside a sized mate sets that mate to its floor")
    func stopBesideASizedMate() throws {
        let three = RunZone(
            members: Array(ids[0..<3]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        let sized = context(focus: 2, sizes: [1: 500], tails: [2])
        let stop = try #require(
            three.stopShortOfPush(ids[1], toward: .start, in: sized)
        )
        expectEqual(stop.sizes[ids[0]], .some(0.3))
        let share = try #require(stop.sizes[ids[1]] ?? nil)
        #expect(abs(share - 0.69) < 0.001)
        #expect(!stop.movesRun)
    }

    @Test("A hold's stop writes nothing in a run hiding nothing")
    func stopInARunHidingNothing() {
        let two = RunZone(
            members: Array(ids[0..<2]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        #expect(
            two.stopShortOfPush(ids[0], toward: .end, in: context(focus: 1))
                == nil
        )
    }

    @Test("A press at the weight's limit in a run hiding nothing pushes")
    func spentWeightPushes() throws {
        let two = RunZone(
            members: Array(ids[0..<2]),
            region: CGRect(x: 0, y: 0, width: 1000, height: 600),
            vertical: false
        )
        var whole = context(focus: 1)
        whole.stackWeights[ids[0]] = StackLayout.weightRange.upperBound
        let run = try #require(two.run(in: whole))
        #expect(!run.hides)
        let press = try #require(
            two.press(ids[0], by: 5, toward: .end, in: whole)
        )
        #expect(press.movesRun)
        expectEqual(press.visible, 0..<1)
        #expect(press.cue == nil)
    }
}
