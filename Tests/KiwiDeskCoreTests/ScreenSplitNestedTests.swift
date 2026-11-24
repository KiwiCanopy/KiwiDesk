import Foundation
import Testing

@testable import KiwiDeskCore

/// Nested splits (#3541): the runs read off a T-junction and a 2×2
/// split, their positional names, sizing one run with a nested
/// member, and a divider snapping into line with another.
@Suite("Screen split nesting")
struct ScreenSplitNestedTests {
    private let whole = ScreenSplit.whole(width: 3440, height: 1440)

    /// Left | (Middle Top / Middle Bottom) | Right.
    private func tJunction() throws -> ScreenSplit {
        let three = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        return try #require(three.evenedOut(holding: 0).splitting(1, .stacked))
    }

    /// Top Left / Top Right over Bottom Left / Bottom Right.
    private func grid() throws -> ScreenSplit {
        try #require(
            whole.splitting(0, .sideBySide)?.splitting(0, .stacked)?
                .splitting(1, .stacked)
        )
    }

    private func valid(_ split: ScreenSplit) -> Bool {
        ScreenArea.problem(with: split.areas, width: 3440, height: 1440)
            == nil
    }

    @Test func tJunctionRunsAndNames() throws {
        let split = try tJunction()
        #expect(valid(split))
        #expect(split.axis == nil)
        let runs = split.runs
        #expect(runs.map(\.axis) == [.sideBySide, .stacked])
        #expect(runs[0].members.map(\.areas) == [[0], [1, 3], [2]])
        #expect(runs[1].depth == 1)
        #expect(split.run(holding: 0) == runs[0])
        #expect(split.run(holding: 3) == runs[1])
        #expect(
            split.positions
                == [
                    0: [.left], 1: [.middle, .top],
                    3: [.middle, .bottom], 2: [.right],
                ]
        )
    }

    @Test func gridPathsRunOuterFirst() throws {
        let split = try grid()
        #expect(valid(split))
        #expect(split.positions[0] == [.left, .top])
        #expect(split.positions[3] == [.right, .bottom])
    }

    @Test func aMiddleOfAMiddleKeepsBothWords() throws {
        let rows = try #require(
            whole.splitting(0, .stacked)?.splitting(1, .stacked)
        )
        let middle = try #require(
            rows.evenedOut(holding: 0).splitting(1, .sideBySide)?
                .splitting(1, .sideBySide)
        )
        let even = middle.evenedOut(holding: 1)
        #expect(valid(even))
        let ids = ScreenArea.readingOrder(even.areas).map(\.id)
        #expect(
            ids.map { even.positions[$0] ?? [] }
                == [
                    [.top], [.middle, .left], [.middle, .middle],
                    [.middle, .right],
                    [.bottom],
                ]
        )
    }

    @Test func aRunOfFourNumbersEveryArea() throws {
        let four = try #require(
            whole.splitting(0, .sideBySide)?.splitting(0, .sideBySide)?
                .splitting(1, .sideBySide)?.splitting(0, .stacked)
        )
        #expect(valid(four))
        let ids = ScreenArea.readingOrder(four.areas).map(\.id)
        #expect(
            ids.map { four.positions[$0] ?? [] }
                == (1...5).map { [.numbered($0)] }
        )
    }

    @Test func evenOutReachesOnlyTheSelectionsRun() throws {
        let split = try tJunction()
        let column = try #require(split.run(holding: 1))
        let tall = try #require(
            split.setting(
                member: 0,
                of: column,
                to: 1000,
                givingWay: 1,
                floor: 300
            )
        ).split
        let inner = tall.evenedOut(holding: 3)
        #expect(inner.run(holding: 3)?.lengths == [720, 720])
        #expect(inner.run(holding: 0) == tall.run(holding: 0))
    }

    @Test func aNestedMemberResizesWhole() throws {
        let split = try tJunction()
        let run = try #require(split.run(holding: 0))
        let set = try #require(
            split.setting(
                member: 1,
                of: run,
                to: 1600,
                givingWay: 2,
                floor: 300
            )
        )
        #expect(valid(set.split))
        let middle = set.split.areas.filter { [1, 3].contains($0.id) }
        #expect(middle.allSatisfy { $0.x == 1147 && $0.w == 1600 })
        #expect(set.split.run(holding: 0)?.lengths == [1147, 1600, 693])
    }

    @Test func aNestedMembersFloorIsItsAreas() throws {
        // Middle split again side by side: its floor is two areas'.
        let split = try #require(try tJunction().splitting(1, .sideBySide))
        let run = try #require(split.run(holding: 0))
        let index = try #require(run.member(holding: 1))
        #expect(split.memberFloor(of: index, in: run, floor: 300) >= 600)
        let set = try #require(
            split.setting(
                member: index,
                of: run,
                to: 200,
                givingWay: 2,
                floor: 300
            )
        )
        #expect(valid(set.split))
        let narrow = set.split.areas
            .filter { run.members[index].areas.contains($0.id) }
            .map(\.w).min()
        #expect((narrow ?? 0) >= 300)
        // 574 of 1147 mapped to 601 is 300.76: the shared edge rounds.
        #expect(set.length == 601)
        #expect(set.split.areas.first { $0.id == 1 }?.w == 301)
        #expect(set.split.areas.first { $0.id == 4 }?.w == 300)
    }

    @Test func aDividerSnapsInLineWithAnother() throws {
        let split = try grid()
        let cuts = try #require(
            ScreenAreaCuts.cuts(of: split.areas, width: 3440, height: 1440)
        )
        let stacked = cuts.filter { $0.axis == .stacked }
        #expect(stacked.count == 2)
        let left = stacked[0]
        let moved = split.moving(left, to: 600, floor: 300).split
        let movedCuts = try #require(
            ScreenAreaCuts.cuts(of: moved.areas, width: 3440, height: 1440)
        )
        let right = try #require(
            movedCuts.last { $0.axis == .stacked && $0.position == 720 }
        )
        let snapped = moved.snapped(
            605,
            for: right,
            width: 3440,
            height: 1440,
            tolerance: 10
        )
        #expect(snapped.position == 600)
        #expect(snapped.snap == .divider)
    }

    @Test func aSegmentMovesAlone() throws {
        let split = try grid()
        let cuts = try #require(
            ScreenAreaCuts.cuts(of: split.areas, width: 3440, height: 1440)
        )
        let left = try #require(cuts.first { $0.axis == .stacked })
        let moved = split.moving(left, to: 500, floor: 300).split
        #expect(valid(moved))
        let right = moved.areas.filter { $0.x == 1720 }
        #expect(right.map(\.h).sorted() == [720, 720])
    }

    @Test func threeRunsDeepNumbersEveryArea() throws {
        let deep = try #require(
            try tJunction().splitting(1, .sideBySide)
        )
        #expect(valid(deep))
        #expect(deep.runs.contains { $0.depth == 2 })
        let ids = ScreenArea.readingOrder(deep.areas).map(\.id)
        #expect(
            ids.map { deep.positions[$0] ?? [] }
                == (1...ids.count).map { [.numbered($0)] }
        )
    }

    @Test func evenOutKeepsANestedMembersFloor() throws {
        // [300 | rest], the rest split top to bottom, its top split
        // again so a 300-wide area sits at its far edge.
        let pair = try #require(whole.splitting(0, .sideBySide))
        let run = try #require(pair.run(holding: 0))
        let lopsided = try #require(
            pair.setting(
                member: 0,
                of: run,
                to: 300,
                givingWay: 1,
                floor: 300
            )
        ).split
        let stacked = try #require(lopsided.splitting(1, .stacked))
        let top = try #require(stacked.splitting(1, .sideBySide))
        let topRun = try #require(top.run(holding: 1))
        let narrow = try #require(
            top.setting(
                member: 1,
                of: topRun,
                to: 300,
                givingWay: 0,
                floor: 300
            )
        ).split
        #expect(valid(narrow))
        let even = narrow.evenedOut(holding: 0, floor: 300)
        #expect(valid(even))
        #expect(even.areas.allSatisfy { $0.w >= 300 })
        // The nested member cannot give a point, so nothing moves.
        #expect(even == narrow)
    }

    @Test func aMemberIsNamedByItsOwnWord() throws {
        let split = try tJunction()
        let run = try #require(split.run(holding: 0))
        #expect(split.position(ofMember: 1, in: run) == [.middle])
        #expect(split.position(ofMember: 0, in: run) == [.left])
    }
}
