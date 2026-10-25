import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let ids = (1...9).map { WindowID(UInt32($0)) }
private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

@MainActor
private func isParked(_ frame: CGRect?) -> Bool {
    guard let frame else { return false }
    return TilingEngine.looksStashed(frame, in: screen)
}

/// Usable 1900 × 1060 at gap 10, min 300: a fixed 3 × 2 grid fits.
private func context(
    focused: WindowID? = nil,
    autoSize: Bool = false,
    rowsFirst: Bool = false,
    columns: Int = 3,
    rows: Int = 2
) -> LayoutContext {
    var context = LayoutContext(
        bounds: screen,
        gaps: .uniform(10),
        focused: focused
    )
    context.grid.type = .rigid
    context.grid.columns = columns
    context.grid.rows = rows
    context.grid.autoSize = autoSize
    context.grid.splitDirection = rowsFirst ? .vertical : .horizontal
    return context
}

/// Grid's overflow scrolls through its last track (#2541): the
/// windows past the cells wait parked, focus scrolls them in, and
/// a fixed grid's columns × rows is a limit the screen lowers.
@Suite("Grid run")
@MainActor
struct GridRunTests {
    @Test("A fixed grid's last row shows exactly its cells")
    func lastRowShowsItsCells() throws {
        let ctx = context()
        let frames = GridLayout().calculateGeometry(for: ids, in: ctx)
        let shape = try #require(GridLayout.shape(count: 9, in: ctx))
        #expect(shape.scrolls)
        // w1…w3 fill the first row; the last row shows w4…w6 in
        // its three cells and parks w7…w9.
        let top = try #require(frames[ids[0]])
        for index in 3..<6 {
            let cell = try #require(frames[ids[index]])
            #expect(cell.minY > top.maxY)
            #expect(abs(cell.width - top.width) < 0.01)
        }
        for index in 6..<9 { #expect(isParked(frames[ids[index]])) }
    }

    @Test("Focus on a hidden window scrolls it into the last cell")
    func focusScrollsIn() throws {
        let ctx = context(focused: ids[8])
        let frames = GridLayout().calculateGeometry(for: ids, in: ctx)
        let last = try #require(frames[ids[8]])
        #expect(abs(last.maxX - 1910) < 0.01)
        #expect(isParked(frames[ids[3]]))
        #expect(isParked(frames[ids[5]]))
        #expect(!isParked(frames[ids[6]]))
        // The rows above never move for the run.
        let rest = GridLayout().calculateGeometry(for: ids, in: context())
        #expect(frames[ids[0]] == rest[ids[0]])
    }

    @Test("Rows first scrolls the last column")
    func rowsFirstScrollsTheLastColumn() throws {
        let ctx = context(rowsFirst: true)
        let zone = try #require(GridLayout.zones(for: ids, in: ctx)?.first)
        #expect(zone.vertical)
        #expect(zone.members == Array(ids[4...]))
        #expect(zone.region.maxX == ctx.usable.maxX)
    }

    @Test("RunCover reads a grid's run")
    func coverReadsTheRun() throws {
        let cover = try #require(
            RunCover.of(space: "1", mode: .grid, tiled: ids, in: context())
        )
        #expect(cover.runs.count == 1)
        #expect(Set(cover.behind.keys) == Set(ids[6...]))
        #expect(cover.tails == [ids[5]])
    }

    @Test("A grid that fits scrolls nothing")
    func fittingGridScrollsNothing() throws {
        let zones = try #require(
            GridLayout.zones(for: Array(ids.prefix(6)), in: context())
        )
        #expect(zones.isEmpty)
    }

    @Test("Typed columns are a limit the screen lowers")
    func typedColumnsAreALimit() throws {
        let ctx = context(columns: 9, rows: 9)
        let shape = try #require(GridLayout.shape(count: 9, in: ctx))
        // floor(1900 / 310) = 6 columns, floor(1060 / 310) = 3.
        #expect(shape.columns == 6)
        #expect(shape.rows == 3)
    }

    @Test("An auto-sized last track shows as many as fit")
    func autoSizeRunsByFloor() throws {
        // Auto-size: 6 × 3 cells at 300 pt; 20 windows overflow.
        let many = (1...20).map { WindowID(UInt32($0)) }
        let auto = try #require(
            GridLayout.zones(for: many, in: context(autoSize: true))?
                .first
        )
        #expect(auto.slots == nil)
        let fixed = try #require(
            GridLayout.zones(for: ids, in: context())?.first
        )
        #expect(fixed.slots?.count == 3)
    }

    @Test("A hidden member's floor lifts the last row's height")
    func hiddenFloorLiftsTheRow() throws {
        var ctx = context()
        ctx.sizeBounds = [
            ids[8]: EffectiveSizeBound(height: [
                .init(asked: 520, answered: 700),
                .init(asked: 400, answered: 700),
            ])
        ]
        let shape = try #require(GridLayout.shape(count: 9, in: ctx))
        let floors = GridLayout.trackFloors(
            windows: ids,
            shape: shape,
            horizontal: false,
            context: ctx
        )
        #expect(floors.last?.size == 700)
        #expect(floors.last?.carrier == ids[8])
        // Along the run, no member lifts a column.
        let columns = GridLayout.trackFloors(
            windows: ids,
            shape: shape,
            horizontal: true,
            context: ctx
        )
        #expect(columns.allSatisfy { $0.carrier == nil })
    }

    @Test("A resize finds a shown run member's cell, not a hidden one")
    func cellIndicesSkipHidden() throws {
        let ctx = context(focused: ids[8])
        let shape = try #require(GridLayout.shape(count: 9, in: ctx))
        let cells = GridLayout.cellIndices(of: ids, shape: shape, in: ctx)
        #expect(cells[ids[8]] == 5)
        #expect(cells[ids[6]] == 3)
        #expect(cells[ids[3]] == nil)
        #expect(cells[ids[0]] == 0)
    }
}
