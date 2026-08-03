import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Grid preview's capacity ceiling and the pile past it
/// (#712).
///
/// `GridLayout` gives both grid types one ceiling — the typed
/// columns × rows, or the screen-computed dimensions under
/// `auto_size` — and cascades the excess in the last cell. The
/// preview modelled none of it: `dynamicDims` called
/// `GridLayout.balanced` alone, so dragging the count subdivided
/// forever, and the rigid arm mapped every overflow window to one
/// rect, which read as the cell darkening rather than as a pile.
///
/// **What these assert is the ceiling's *consequences*, not the
/// call.** A schematic that called `dimensions` and then drew a
/// constant would satisfy a scan; it cannot satisfy "the grid
/// stops growing" and "the surplus is piled" at every count.
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
            #expect(panel.piledCount == schematic.piledCount)
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

    /// Past capacity the engine tiles `capacity - 1` and piles
    /// the rest. The pile has to *grow* with the count — the
    /// defect was a pile that existed in the cell list and looked
    /// identical at every count.
    @Test("the surplus piles, and the pile deepens")
    func theSurplusPiles() {
        var previous = 0
        var overflowed = 0
        for count in LayoutSchematic.windowCountRange {
            let schematic = grid(
                columns: 2,
                rows: 2,
                type: .rigid,
                windows: count
            )
            let piled = schematic.piledCount
            if count <= schematic.capacity {
                // Exactly zero, not "at most one": the engine
                // takes its overflow branch only PAST capacity,
                // and a `<= 1` here was written around an
                // off-by-one in `piledCount` rather than
                // catching it (code review, 2026-08-03).
                #expect(piled == 0)
            } else {
                overflowed += 1
                #expect(piled > 1)
                #expect(piled > previous)
            }
            previous = piled
        }
        // The else branch has to have run, or the loop asserted
        // `0 == 0` twelve times and called it coverage.
        #expect(overflowed > 0)
    }

    /// Every piled tile gets its own rect. Identical rects are
    /// what made the last cell darken instead of pile: the tiles
    /// were there, stacked, summing their accent alpha (#712).
    @Test("piled tiles are offset, never drawn at one rect")
    func piledTilesAreOffset() {
        let schematic = grid(
            columns: 2,
            rows: 2,
            type: .rigid,
            windows: 12
        )
        // The panel's real drawing area, not an invented size —
        // a fixture that reasons from geometry pins it
        // (`.claude/rules/tests.md`). Width is the pane's, so a
        // representative one; the height is the scale's own, less
        // the 6 pt padding the body applies.
        let cells = schematic.gridCells(
            CGSize(
                width: 600,
                height: SchematicScale.panel.height - 12
            ),
            cols: schematic.dims.columns,
            rows: schematic.dims.rows,
            ids: schematic.ids
        )
        // Only the pile: tiled cells legitimately share a row's
        // y, so asserting over every cell would be asserting the
        // grid, not the cascade.
        let piled = cells.filter {
            if case .piled = $0.kind { return true }
            return false
        }
        // A filter result with no floor passes over zero
        // elements — every assertion below would then hold
        // vacuously (guard-prover, 2026-08-03).
        #expect(piled.count > 0)
        #expect(piled.count == schematic.piledCount)
        let origins = piled.map(\.rect.origin.y)
        #expect(Set(origins).count == origins.count)
        // Each reveals the one beneath by exactly the family's
        // offset, so the pile reads the same as Stack's and
        // Track's rather than as a colour.
        for (a, b) in zip(origins, origins.dropFirst()) {
            #expect(b - a == LayoutSchematic.cascadeOffset)
        }
        // Nothing is dropped on the way into the pile: every
        // window is either a cell or counted by a `+N` chip.
        let hidden = cells.reduce(0) { sum, cell in
            if case .piled(_, let n) = cell.kind { return sum + n }
            return sum
        }
        #expect(cells.count + hidden == schematic.ids.count)
    }

    /// The pile stays inside the cell that owns it. Reveals that
    /// outrun the cell height march the tiles off the canvas,
    /// where the clip eats them and the picture shows fewer
    /// windows than the caption claims (code review, 2026-08-03).
    @Test("the pile never leaves its cell")
    func thePileStaysInItsCell() {
        let schematic = grid(
            columns: 1,
            rows: 6,
            type: .rigid,
            windows: 12
        )
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
        for cell in cells {
            #expect(cell.rect.maxY <= size.height + 0.5)
            #expect(cell.rect.maxX <= size.width + 0.5)
        }
        // What did not fit is accounted for, not dropped — and
        // something did not fit, or this proves nothing.
        let piled = cells.compactMap { cell -> Int? in
            if case .piled(_, let hidden) = cell.kind {
                return hidden
            }
            return nil
        }
        #expect(piled.count > 0)
        #expect(piled.reduce(0, +) > 0)
        #expect(piled.reduce(0, +) + piled.count == schematic.piledCount)
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

    /// The engine's OVERFLOW branch lays its tiled prefix out
    /// row-major whatever `splitDirection` says, unlike its
    /// normal fill. Only a rows-first grid past capacity can tell
    /// the two apart — every other fixture here is columns-first,
    /// where the expressions coincide, so this was watched by
    /// nothing tree-wide (guard-prover, 2026-08-03).
    @Test("a rows-first grid overflows the way the engine does")
    func rowsFirstOverflowFollowsTheEngine() {
        let schematic = GridSchematic(
            columns: 3,
            rows: 2,
            type: .rigid,
            fillEmptySpace: false,
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
        let tiled = cells.filter {
            if case .window = $0.kind { return true }
            return false
        }
        #expect(tiled.count == schematic.capacity - 1)
        // Row-major: the first `cols` tiles share a row, so their
        // y origins repeat before x does. Column-major would put
        // the first `rows` in one column instead.
        let firstRow = tiled.prefix(schematic.dims.columns)
        #expect(Set(firstRow.map(\.rect.origin.y)).count == 1)
        #expect(
            Set(firstRow.map(\.rect.origin.x)).count
                == schematic.dims.columns
        )
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
            fillEmptySpace: false,
            autoSize: autoSize,
            splitDirection: .horizontal,
            placement: .last,
            windows: windows
        )
    }
}
