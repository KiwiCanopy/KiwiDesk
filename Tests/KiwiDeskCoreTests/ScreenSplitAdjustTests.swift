import Foundation
import Testing

@testable import KiwiDeskCore

/// The editor's Core answers (#3517 rulings 3, 15, 25, 26):
/// positional names, the floor, a divider's move and snaps, and a
/// typed size with the area that gives way.
@Suite("Screen split adjustments")
struct ScreenSplitAdjustTests {
    private let whole = ScreenSplit.whole(width: 3440, height: 1440)

    private func three() throws -> ScreenSplit {
        try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
    }

    @Test func positionsFollowCountAndAxis() throws {
        #expect(whole.positions.isEmpty)
        #expect(whole.axis == nil)
        let two = try #require(whole.splitting(0, .stacked))
        #expect(two.axis == .stacked)
        #expect(two.positions == [0: [.top], 1: [.bottom]])
        let pair = try #require(whole.splitting(0, .sideBySide))
        #expect(pair.positions == [0: [.left], 1: [.right]])
        let tall = try #require(two.splitting(1, .stacked))
        #expect(tall.positions == [0: [.top], 1: [.middle], 2: [.bottom]])
        let split = try three()
        #expect(split.positions == [0: [.left], 1: [.middle], 2: [.right]])
        let four = try #require(split.splitting(2, .sideBySide))
        #expect(
            four.positions
                == [
                    0: [.numbered(1)], 1: [.numbered(2)],
                    2: [.numbered(3)], 3: [.numbered(4)],
                ]
        )
    }

    @Test func evenIsReadFromTheLengths() throws {
        let split = try three()
        let run = try #require(split.run(holding: 0))
        #expect(run.lengths == [1720, 860, 860])
        #expect(split.evenedOut(holding: 0) != split)
        let even = split.evenedOut(holding: 0)
        let evenRun = try #require(even.run(holding: 0))
        #expect(evenRun.lengths == [1147, 1147, 1146])
        #expect(even.evenedOut(holding: 0) == even)
        #expect(whole.run(holding: 0) == nil)
    }

    @Test func floorIsTheLargestTilingLayout() {
        var settings = TilingSettings()
        settings.minWindowSizes = MinWindowSizes(all: .square(300))
        settings.minWindowSizes.bsp = MinSize(width: 640, height: 200)
        settings.minWindowSizes.floating = .square(2000)
        #expect(settings.areaFloor(along: .sideBySide) == 640)
        #expect(settings.areaFloor(along: .stacked) == 300)
        settings.minWindowSizes = MinWindowSizes(all: .square(10))
        #expect(
            settings.areaFloor(along: .stacked) == ScreenArea.minimumSide
        )
    }

    @Test func dividerStopsAtTheFloor() throws {
        let split = try three()
        let cut = try #require(
            ScreenAreaCuts.cuts(of: split.areas, width: 3440, height: 1440)?
                .first
        )
        let moved = split.moving(cut, to: 1000, floor: 300)
        #expect(moved.position == 1000)
        #expect(moved.split.run(holding: 0)?.lengths == [1000, 1580, 860])
        let stopped = split.moving(cut, to: 2400, floor: 300)
        #expect(stopped.position == 2280)
        #expect(stopped.split.run(holding: 0)?.lengths == [2280, 300, 860])
        #expect(split.moving(cut, to: 10, floor: 300).position == 300)
    }

    @Test func dividerSnapsToFractionsAndEven() throws {
        let split = try three()
        let cut = try #require(
            ScreenAreaCuts.cuts(of: split.areas, width: 3440, height: 1440)?
                .first
        )
        let third = split.snapped(
            1140,
            for: cut,
            width: 3440,
            height: 1440,
            tolerance: 20
        )
        #expect(third.position == 1147)
        #expect(third.snap == .fraction(1, 3))
        let free = split.snapped(
            1500,
            for: cut,
            width: 3440,
            height: 1440,
            tolerance: 20
        )
        #expect(free.position == 1500)
        #expect(free.snap == nil)
        let snaps = split.snaps(for: cut, width: 3440, height: 1440)
        #expect(snaps.contains { $0.snap == .even && $0.position == 1290 })
        // A cut past the origin over an odd span: the leading area
        // takes the odd point, as a split does.
        let uneven = split.resized([1721, 859, 860], axis: .sideBySide)
        let second = try #require(
            ScreenAreaCuts.cuts(of: uneven.areas, width: 3440, height: 1440)?
                .last
        )
        #expect(
            uneven.snaps(for: second, width: 3440, height: 1440)
                .contains { $0.snap == .even && $0.position == 2581 }
        )
    }

    @Test func typedSizeMovesExactlyTwoAreas() throws {
        let split = try three()
        let run = try #require(split.run(holding: 0))
        func lengths(_ s: ScreenSplit) -> [Int] {
            ScreenArea.readingOrder(s.areas).map(\.w)
        }
        let set = try #require(
            split.setting(
                member: 2,
                of: run,
                to: 800,
                givingWay: 1,
                floor: 300
            )
        )
        #expect(set.length == 800)
        #expect(lengths(set.split) == [1720, 920, 800])
        let clamped = try #require(
            split.setting(
                member: 0,
                of: run,
                to: 2500,
                givingWay: 1,
                floor: 300
            )
        )
        #expect(clamped.length == 2280)
        #expect(lengths(clamped.split) == [2280, 300, 860])
        #expect(
            ScreenArea.problem(
                with: clamped.split.areas,
                width: 3440,
                height: 1440
            ) == nil
        )
        #expect(
            split.setting(
                member: 0,
                of: run,
                to: 10,
                givingWay: 0,
                floor: 1
            ) == nil
        )
    }

    @Test func percentsAddUpToAHundred() throws {
        let split = try three()
        let even = try #require(split.evenedOut(holding: 0).run(holding: 0))
        #expect(even.percents == [34, 33, 33])
        #expect(try three().run(holding: 0)?.percents == [50, 25, 25])
        #expect(even.points(percent: 50) == 1720)
    }
}
