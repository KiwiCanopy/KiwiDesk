import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Grid preview's capacity ceiling and the run past it
/// (#712, #2541).
///
/// `GridLayout` gives both grid types one ceiling — the typed
/// columns × rows, or the screen-computed dimensions under
/// `auto_size` — and scrolls the excess through the last track.
///
/// **What these assert is the ceiling's *consequences*, not the
/// call.** A schematic that called `dimensions` and then drew a
/// constant would satisfy a scan; it cannot satisfy "the grid
/// stops growing" and "the surplus waits beyond the last track"
/// at every count.
@Suite("Layout preview grid capacity")
@MainActor
struct LayoutSchematicCapacityTests {
    /// With auto-size off the ceiling is the user's own setting,
    /// for **dynamic** as much as rigid — the half the preview
    /// used to omit entirely.
    @Test("the typed dimensions cap a dynamic grid too")
    func dynamicStopsAtTheTypedCeiling() {
        for count in LayoutSchematic.windowCountRange {
            // 8 x 1 on purpose: above BOTH clamps the deleted
            // legibility ceiling used (tile 4, panel 6), so the
            // invariance assertions below are load-bearing. A
            // 2 x 2 fixture sat under both and stayed green under
            // the very code it names (guard-prover, 2026-08-03).
            let schematic = grid(
                columns: 8,
                rows: 1,
                type: .dynamic,
                windows: count
            )
            #expect(schematic.cap == (columns: 8, rows: 1))
            // Scale-invariant: the ceiling is the layout's rule,
            // so a thumbnail and the panel must agree about it.
            // An earlier cut clamped the rule to what the canvas
            // could draw and the two disagreed (#712).
            var panel = schematic
            panel.scale = .panel
            #expect(panel.cap == schematic.cap)
            #expect(panel.capacity == schematic.capacity)
            #expect(panel.hiddenCount == schematic.hiddenCount)
            #expect(schematic.dims.columns <= 8)
            #expect(schematic.dims.rows <= 1)
        }
        // And it genuinely balances *below* the ceiling rather
        // than snapping to it: a cap is not a floor.
        let small = grid(
            columns: 4,
            rows: 4,
            type: .dynamic,
            windows: 3
        )
        #expect(small.dims.columns * small.dims.rows < 16)
    }

    /// Auto-size is the one arm the canvas cannot compute, since
    /// the real ceiling fits minimum-size cells against a real
    /// display. It stands in, and the stand-in is the ceiling.
    /// Falsifiable on both sides: the stand-in is used AND the
    /// typed dimensions are not. An earlier cut asserted
    /// `!isClamped`, whose first term was `!autoSize` — trivially
    /// true for this very fixture, so it could not fail whatever
    /// the cap did (code review, 2026-08-03).
    @Test("auto-size uses the canvas stand-in, not the typed dims")
    func autoSizeUsesTheStandIn() {
        let schematic = grid(
            columns: 9,
            rows: 9,
            type: .rigid,
            windows: 6,
            autoSize: true
        )
        #expect(schematic.cap == LayoutSchematic.gridAutoSizeCap)
        #expect(schematic.cap != (columns: 9, rows: 9))
        // And turning auto-size off follows the typed dims, so
        // the branch above is a choice and not a constant.
        let typed = grid(
            columns: 9,
            rows: 9,
            type: .rigid,
            windows: 6
        )
        #expect(typed.cap == (columns: 9, rows: 9))
    }

    /// Past capacity the last track scrolls: the windows waiting
    /// beyond it grow with the count, and none waits at or under
    /// capacity (#2541).
    @Test("the surplus waits beyond the last track, and grows")
    func theSurplusScrolls() {
        var previous = 0
        var overflowed = 0
        for count in LayoutSchematic.windowCountRange {
            let schematic = grid(
                columns: 2,
                rows: 2,
                type: .rigid,
                windows: count
            )
            let hidden = schematic.hiddenCount
            if count <= schematic.capacity {
                #expect(hidden == 0)
            } else {
                overflowed += 1
                #expect(hidden > previous)
            }
            previous = hidden
        }
        // The else branch has to have run, or the loop asserted
        // `0 == 0` twelve times and called it coverage.
        #expect(overflowed > 0)
    }

    /// A full grid draws every cell once — the last track's cells
    /// holding the run, each its own rect — and every window is
    /// either drawn or counted by a `+N` chip (#2541).
    @Test("the last track shows its cells and counts the rest")
    func lastTrackShowsItsCells() {
        let schematic = grid(
            columns: 2,
            rows: 2,
            type: .rigid,
            windows: 12
        )
        // The panel's real drawing area, not an invented size —
        // a fixture that reasons from geometry pins it
        // (`.claude/rules/tests.md`).
        let size = CGSize(
            width: 600,
            height: SchematicScale.panel.height - 12
        )
        let cells = schematic.gridCells(
            size,
            cols: schematic.dims.columns,
            rows: schematic.dims.rows,
            ids: schematic.ids
        )
        #expect(cells.count == schematic.capacity)
        let origins = cells.map(\.rect.origin)
        #expect(
            Set(origins.map { "\($0.x),\($0.y)" }).count
                == cells.count
        )
        let run = cells.compactMap { cell -> Int? in
            if case .scrolled(_, let n) = cell.kind { return n }
            return nil
        }
        #expect(run.count == schematic.dims.columns)
        #expect(run.reduce(0, +) == schematic.hiddenCount)
        #expect(cells.count + run.reduce(0, +) == schematic.ids.count)
        for cell in cells {
            #expect(cell.rect.maxY <= size.height + 0.5)
            #expect(cell.rect.maxX <= size.width + 0.5)
        }
    }

    /// The captions state the ceiling in words. Nothing else
    /// stops them stating a different one from the picture, and
    /// two of #712's three arms were exactly that — a caption
    /// promising a ceiling the drawing did not have. Both were
    /// silently reintroducible until this (guard-prover,
    /// 2026-08-03).
    @Test("every caption states the ceiling the grid actually uses")
    func captionsStateTheRealCeiling() {
        // Rigid, typed: the caption's numbers are the ceiling's.
        let rigid = grid(
            columns: 5,
            rows: 3,
            type: .rigid,
            windows: 6
        )
        #expect(rigid.caption.contains("5 × 3"))
        // Dynamic reads the same ceiling — it balances up to it.
        let dynamic = grid(
            columns: 5,
            rows: 3,
            type: .dynamic,
            windows: 6
        )
        #expect(dynamic.caption.contains("5 × 3"))
        // Auto-size states the stand-in, derived rather than
        // written out: a literal here is what would leave eleven
        // catalogs quoting a number the code no longer uses.
        let auto = grid(
            columns: 5,
            rows: 3,
            type: .rigid,
            windows: 6,
            autoSize: true
        )
        let cap = LayoutSchematic.gridAutoSizeCap
        #expect(
            auto.caption.contains("\(cap.columns) × \(cap.rows)")
        )
        #expect(!auto.caption.contains("5 × 3"))
    }

    /// The incoming window takes the focus, so the run ends at it
    /// (`.last`) or starts at it (`.afterFocused` at the run's
    /// first cell), and the windows beyond are counted on the end
    /// they wait at (#2541).
    @Test("the incoming window scrolls in, counted from its ends")
    func incomingWindowScrollsIn() {
        func run(
            _ placement: SpawnPlacement
        ) -> [(TileKindName, Int)] {
            let schematic = GridSchematic(
                columns: 2,
                rows: 2,
                type: .rigid,
                fillEmptyCells: false,
                autoSize: false,
                splitDirection: .horizontal,
                placement: placement,
                windows: 12
            )
            return schematic.gridCells(
                CGSize(width: 600, height: 228),
                cols: schematic.dims.columns,
                rows: schematic.dims.rows,
                ids: schematic.ids
            ).compactMap { cell in
                guard case .scrolled(let tile, let n) = cell.kind
                else { return nil }
                return (tile == .new ? .new : .other, n)
            }
        }
        // Eleven windows and the new one: 12 - 4 cells wait.
        let last = run(.last)
        #expect(last.count == 2)
        #expect(last.last?.0 == .new)
        #expect(last.first?.1 == 8)
        #expect(last.last?.1 == 0)
        let after = run(.afterFocused)
        #expect(after.count == 2)
        #expect(after.first?.0 == .new)
        #expect(after.first?.1 == 0)
        #expect(after.last?.1 == 8)
    }

    private enum TileKindName { case new, other }

    /// A rows-first grid fills down its columns and scrolls its
    /// LAST COLUMN, along the fill order like the engine (#2541).
    /// Every other fixture here is columns-first, where a row run
    /// and a column run cannot be told apart.
    @Test("a rows-first grid scrolls its last column")
    func rowsFirstScrollsTheLastColumn() {
        let schematic = GridSchematic(
            columns: 3,
            rows: 2,
            type: .rigid,
            fillEmptyCells: false,
            autoSize: false,
            splitDirection: .vertical,
            placement: .last,
            windows: 12
        )
        let size = CGSize(width: 600, height: 228)
        let cells = schematic.gridCells(
            size,
            cols: schematic.dims.columns,
            rows: schematic.dims.rows,
            ids: schematic.ids
        )
        let run = cells.filter {
            if case .scrolled = $0.kind { return true }
            return false
        }
        #expect(run.count == schematic.dims.rows)
        #expect(Set(run.map(\.rect.origin.x)).count == 1)
        let lastX = cells.map(\.rect.origin.x).max()
        #expect(run.first?.rect.origin.x == lastX)
    }

    private func grid(
        columns: Int,
        rows: Int,
        type: GridParams.GridType,
        windows: Int,
        autoSize: Bool = false
    ) -> GridSchematic {
        GridSchematic(
            columns: columns,
            rows: rows,
            type: type,
            fillEmptyCells: false,
            autoSize: autoSize,
            splitDirection: .horizontal,
            placement: .last,
            windows: windows
        )
    }
}
