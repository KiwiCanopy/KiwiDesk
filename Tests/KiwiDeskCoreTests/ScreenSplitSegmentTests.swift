import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌥-drag moves one segment of a joined divider (#3611): the piece
/// runs between points where areas on both sides meet the line, and
/// moving it edits only the rects beside it.
@Suite("Screen split segments (#3611)")
struct ScreenSplitSegmentTests {
    private func area(
        _ id: Int,
        _ x: Int,
        _ y: Int,
        _ w: Int,
        _ h: Int
    ) -> ScreenArea {
        ScreenArea(id: id, x: x, y: y, w: w, h: h)
    }

    private func cuts(_ split: ScreenSplit) throws -> [ScreenAreaCut] {
        try #require(
            ScreenAreaCuts.cuts(
                of: split.areas,
                width: split.extent.width,
                height: split.extent.height
            )
        )
    }

    /// Rows split top to bottom, each split side by side at 1000:
    /// the walk reads one full-height divider.
    private var grid: ScreenSplit {
        ScreenSplit(areas: [
            area(0, 0, 0, 1000, 500), area(1, 1000, 0, 1000, 500),
            area(2, 0, 500, 1000, 500), area(3, 1000, 500, 1000, 500),
        ])
    }

    private func joined(_ split: ScreenSplit) throws -> ScreenAreaCut {
        try #require(
            try cuts(split).first {
                $0.axis == .sideBySide && $0.start == 0
                    && $0.end == split.extent.height
            }
        )
    }

    @Test func pointerPicksItsRow() throws {
        let line = try joined(grid)
        #expect(grid.isJoined(line))
        let top = grid.segment(of: line, at: 200)
        #expect(top.start == 0 && top.end == 500)
        #expect(top.leading == [0] && top.trailing == [1])
        let bottom = grid.segment(of: line, at: 700)
        #expect(bottom.start == 500 && bottom.end == 1000)
        #expect(bottom.leading == [2] && bottom.trailing == [3])
        // A pointer on the break takes the segment after it.
        #expect(grid.segment(of: line, at: 500) == bottom)
    }

    @Test func movingOneRowLeavesTheOther() throws {
        let line = try joined(grid)
        let top = grid.segment(of: line, at: 200)
        let moved = grid.movingSegment(top, to: 1300, floor: 100)
        #expect(moved.position == 1300)
        let byID = Dictionary(
            uniqueKeysWithValues: moved.split.areas.map { ($0.id, $0) }
        )
        #expect(byID[0]?.w == 1300 && byID[1]?.x == 1300)
        #expect(byID[1]?.w == 700)
        #expect(byID[2] == grid.areas[2] && byID[3] == grid.areas[3])
        // The next read sees two dividers, one per row.
        let upright = try cuts(moved.split).filter {
            $0.axis == .sideBySide
        }
        #expect(Set(upright.map(\.position)) == [1000, 1300])
        #expect(upright.allSatisfy { $0.end - $0.start == 500 })
    }

    /// A line no area edge meets from both sides is one segment, so
    /// ⌥ moves it whole, as a plain drag does.
    @Test func teeJunctionIsOneSegment() throws {
        let tee = ScreenSplit(areas: [
            area(0, 0, 0, 1000, 1000),
            area(1, 1000, 0, 1000, 500), area(2, 1000, 500, 1000, 500),
        ])
        let line = try joined(tee)
        let piece = tee.segment(of: line, at: 700)
        #expect(piece == line)
        #expect(!tee.isJoined(line))
        // Mirrored: the split side leads.
        let eet = ScreenSplit(areas: [
            area(0, 0, 0, 1000, 500), area(1, 0, 500, 1000, 500),
            area(2, 1000, 0, 1000, 1000),
        ])
        let other = try joined(eet)
        #expect(eet.segment(of: other, at: 700) == other)
        #expect(!eet.isJoined(other))
    }

    /// Three rows line up; the middle one moves alone and the rects
    /// still read as a split.
    @Test func middleRowMovesAlone() throws {
        let rows = ScreenSplit(areas: [
            area(0, 0, 0, 1000, 300), area(1, 1000, 0, 1000, 300),
            area(2, 0, 300, 1000, 400), area(3, 1000, 300, 1000, 400),
            area(4, 0, 700, 1000, 300), area(5, 1000, 700, 1000, 300),
        ])
        let line = try joined(rows)
        let middle = rows.segment(of: line, at: 500)
        #expect(middle.start == 300 && middle.end == 700)
        #expect(middle.leading == [2] && middle.trailing == [3])
        let moved = rows.movingSegment(middle, to: 800, floor: 100)
        #expect(moved.position == 800)
        #expect(try cuts(moved.split).count == 5)
    }

    /// The line's left box is not cut where its right one is: a
    /// tall area crosses that point, so moving either piece would
    /// leave no divider to read. The line is one segment.
    private var lopsided: ScreenSplit {
        ScreenSplit(areas: [
            area(0, 0, 0, 1000, 300), area(1, 0, 300, 400, 700),
            area(2, 400, 300, 600, 200), area(3, 400, 500, 600, 500),
            area(4, 1000, 0, 1000, 500), area(5, 1000, 500, 1000, 500),
        ])
    }

    @Test func boxNotCutThereIsNoBreak() throws {
        let line = try joined(lopsided)
        #expect(!lopsided.isJoined(line))
        #expect(lopsided.segment(of: line, at: 200) == line)
    }

    /// The belt: a piece whose move leaves no divider to read is
    /// refused where it stands.
    @Test func unreadableMoveIsRefused() throws {
        let line = try joined(lopsided)
        let top = ScreenAreaCut(
            axis: .sideBySide,
            position: 1000,
            start: 0,
            end: 500,
            leading: [0, 2],
            trailing: [4]
        )
        let moved = lopsided.movingSegment(top, to: 1100, floor: 100)
        #expect(moved.position == line.position)
        #expect(moved.split == lopsided)
        #expect(lopsided.moving(top, to: 1100, floor: 100).position == 1100)
    }

    /// A segment stops at the floor of the areas beside it, as a
    /// plain drag does.
    @Test func segmentStopsAtTheFloor() throws {
        let line = try joined(grid)
        let top = grid.segment(of: line, at: 0)
        let moved = grid.movingSegment(top, to: 1990, floor: 100)
        #expect(moved.position == 1900)
    }
}
