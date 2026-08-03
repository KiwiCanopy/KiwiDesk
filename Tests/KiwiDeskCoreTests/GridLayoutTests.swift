import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    grid: (inout GridParams) -> Void = { _ in }
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: .uniform(10)
    )
    grid(&context.grid)
    return context
}

@Suite("Grid dimensions")
struct GridDimensionTests {
    let layout = GridLayout()

    /// A cap large enough never to clamp the balanced result —
    /// isolates the raw auto-balance progression.
    private let looseCap = (columns: 100, rows: 100)

    @Test(
        "Column-first progression matches the spec",
        arguments: [
            (1, 1, 1), (2, 2, 1), (3, 2, 2), (4, 2, 2),
            (5, 3, 2), (6, 3, 2), (7, 3, 3), (9, 3, 3),
            (10, 4, 3),
        ]
    )
    func columnFirst(spec: (n: Int, cols: Int, rows: Int)) {
        var params = GridParams()
        params.splitDirection = .horizontal
        let dims = GridLayout.dimensions(
            count: spec.n,
            params: params,
            cap: looseCap
        )
        #expect(dims.columns == spec.cols)
        #expect(dims.rows == spec.rows)
    }

    @Test(
        "Row-first progression matches the spec",
        arguments: [
            (1, 1, 1), (2, 1, 2), (3, 2, 2), (4, 2, 2),
            (5, 2, 3), (6, 2, 3), (7, 3, 3),
        ]
    )
    func rowFirst(spec: (n: Int, cols: Int, rows: Int)) {
        var params = GridParams()
        params.splitDirection = .vertical
        let dims = GridLayout.dimensions(
            count: spec.n,
            params: params,
            cap: looseCap
        )
        #expect(dims.columns == spec.cols)
        #expect(dims.rows == spec.rows)
    }

    @Test("Dynamic clamps the balanced arrangement to the cap")
    func dynamicRespectsCap() {
        var params = GridParams()
        params.type = .dynamic
        params.splitDirection = .horizontal
        params.columns = 3
        params.rows = 2
        // 9 windows balance to 3x3, but the 3x2 cap holds.
        let dims = GridLayout.dimensions(
            count: 9,
            params: params,
            cap: (3, 2)
        )
        #expect(dims.columns == 3)
        #expect(dims.rows == 2)
    }

    @Test("Dynamic grows the unpinned axis to fill the cap")
    func dynamicFillsMismatchedCap() {
        var params = GridParams()
        params.type = .dynamic
        params.splitDirection = .horizontal
        // 6 windows balance to 3x2 (wide), but the cap is tall
        // (2x3) — columns pin to 2, rows grow to 3 to hold all 6.
        let dims = GridLayout.dimensions(
            count: 6,
            params: params,
            cap: (2, 3)
        )
        #expect(dims.columns == 2)
        #expect(dims.rows == 3)
    }

    @Test("Rigid uses the cap verbatim")
    func rigidUsesCap() {
        var params = GridParams()
        params.type = .rigid
        let dims = GridLayout.dimensions(
            count: 1,
            params: params,
            cap: (4, 2)
        )
        #expect(dims.columns == 4)
        #expect(dims.rows == 2)
    }

    @Test("Auto-size fits more columns than rows on landscape")
    func autoSizeLandscape() {
        var params = GridParams()
        params.autoSize = true
        // 1920x1080 usable, min 300, gap 10: floor(1920/310)=6,
        // floor(1080/310)=3.
        let cap = layout.capDimensions(
            params: params,
            usable: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gapH: 10,
            gapV: 10,
            minSize: 300
        )
        #expect(cap.columns == 6)
        #expect(cap.rows == 3)
    }
}

@Suite("Grid layout")
struct GridLayoutTests {
    let layout = GridLayout()

    @Test("Filled last window spans the empty columns")
    func fillHorizontal() throws {
        let context = makeContext()
        // 3 windows in a 2x2 grid: one empty cell.
        let frames = layout.calculateGeometry(
            for: ids(3),
            in: context
        )
        let last = try #require(frames[w3])
        // Spans both columns of the second row.
        #expect(
            abs(last.width - context.usable.width) < 0.01
        )
    }

    @Test("Without filling, the empty cell stays empty")
    func noFill() throws {
        let context = makeContext { grid in
            grid.fillEmptySpace = false
        }
        let frames = layout.calculateGeometry(
            for: ids(3),
            in: context
        )
        let last = try #require(frames[w3])
        let first = try #require(frames[w1])
        #expect(abs(last.width - first.width) < 0.01)
    }

    @Test("Vertical filling spans remaining rows")
    func fillVertical() throws {
        let context = makeContext { grid in
            grid.splitDirection = .vertical
        }
        let frames = layout.calculateGeometry(
            for: ids(3),
            in: context
        )
        let last = try #require(frames[w3])
        #expect(
            abs(last.height - context.usable.height) < 0.01
        )
    }

    @Test("Rigid grid uses fixed dimensions")
    func rigid() throws {
        let context = makeContext { grid in
            grid.type = .rigid
            grid.columns = 4
            grid.rows = 1
        }
        let frames = layout.calculateGeometry(
            for: ids(4),
            in: context
        )
        let heights = Set(
            frames.values.map { Int($0.height) }
        )
        #expect(heights.count == 1)
        let sorted = frames.values.map(\.minX).sorted()
        #expect(sorted.count == 4)
        #expect(sorted[0] < sorted[3])
    }

    @Test("Rigid honours the arrange (fill) order (#217)")
    func rigidArrange() throws {
        // 2×2 rigid, 3 windows: columns-first (row-major) puts w2
        // top-right; rows-first (column-major) puts it bottom-left.
        func w2Frame(
            _ dir: GridParams.SplitDirection
        ) throws -> CGRect {
            let context = makeContext { grid in
                grid.type = .rigid
                grid.columns = 2
                grid.rows = 2
                grid.splitDirection = dir
            }
            let frames = layout.calculateGeometry(
                for: ids(3),
                in: context
            )
            return try #require(frames[w2])
        }
        let columnsFirst = try w2Frame(.horizontal)
        let rowsFirst = try w2Frame(.vertical)
        #expect(columnsFirst.minX > rowsFirst.minX)
        #expect(columnsFirst.minY < rowsFirst.minY)
    }

    @Test("Rigid overflow stacks excess in the last cell")
    func rigidOverflow() throws {
        let context = makeContext { grid in
            grid.type = .rigid
            grid.columns = 2
            grid.rows = 1
        }
        let frames = layout.calculateGeometry(
            for: ids(4),
            in: context
        )
        let third = try #require(frames[WindowID(3)])
        let fourth = try #require(frames[WindowID(4)])
        // Windows 3 and 4 cascade in the last (right) cell.
        #expect(third.minX == fourth.minX)
        #expect(
            fourth.minY - third.minY == OverlapStack.offset
        )
        #expect(third.minX > context.usable.midX - 1)
    }

    @Test("Dynamic overflow stacks excess past the cap")
    func dynamicOverflow() throws {
        // Cap the dynamic grid at 2x1: the 4th window can no
        // longer balance into a bigger grid, so windows past
        // capacity cascade in the last cell (the rigid path).
        let context = makeContext { grid in
            grid.type = .dynamic
            grid.columns = 2
            grid.rows = 1
        }
        let frames = layout.calculateGeometry(
            for: ids(4),
            in: context
        )
        let second = try #require(frames[WindowID(2)])
        let third = try #require(frames[WindowID(3)])
        let fourth = try #require(frames[WindowID(4)])
        // 2,3,4 cascade in the last (right) cell.
        #expect(second.minX == third.minX)
        #expect(third.minX == fourth.minX)
        #expect(
            third.minY - second.minY == OverlapStack.offset
        )
        #expect(second.minX > context.usable.midX - 1)
    }

    @Test("Auto-size lifts the dynamic cap from the screen")
    func autoSizeGrid() throws {
        // 1920x1080, min 300, gap 10 → 6x3 = 18-cell ceiling.
        // 12 windows balance to 4x3 and all tile; without
        // auto-size the default 3x2 cap would cascade them.
        let context = makeContext { grid in
            grid.autoSize = true
        }
        let frames = layout.calculateGeometry(
            for: ids(12),
            in: context
        )
        #expect(frames.count == 12)
        // 12 distinct cells: no cascade (a cascade shares minX).
        let cells = Set(
            frames.values.map {
                "\(Int($0.minX)),\(Int($0.minY))"
            }
        )
        #expect(cells.count == 12)
    }

    @Test("Tiny screens fall back to the overlap stack")
    func minSizeFallback() throws {
        let context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 500, height: 400)
        )
        let frames = layout.calculateGeometry(
            for: ids(4),
            in: context
        )
        let xs = Set(frames.values.map(\.minX))
        #expect(xs.count == 1)
    }
}
