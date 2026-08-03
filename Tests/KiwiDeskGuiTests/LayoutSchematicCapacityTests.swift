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
            let schematic = grid(
                columns: 2,
                rows: 2,
                type: .dynamic,
                windows: count
            )
            #expect(schematic.cap == (columns: 2, rows: 2))
            #expect(schematic.dims.columns <= 2)
            #expect(schematic.dims.rows <= 2)
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
    @Test("auto-size uses the canvas stand-in, not the typed dims")
    func autoSizeUsesTheStandIn() {
        let schematic = grid(
            columns: 9,
            rows: 9,
            type: .rigid,
            windows: 6,
            autoSize: true
        )
        #expect(schematic.cap == LayoutSchematic.autoSizeCap)
        #expect(!schematic.isClamped)
    }

    /// Past capacity the engine tiles `capacity - 1` and piles
    /// the rest. The pile has to *grow* with the count — the
    /// defect was a pile that existed in the cell list and looked
    /// identical at every count.
    @Test("the surplus piles, and the pile deepens")
    func theSurplusPiles() {
        var previous = 0
        for count in LayoutSchematic.windowCountRange {
            let schematic = grid(
                columns: 2,
                rows: 2,
                type: .rigid,
                windows: count
            )
            let piled = schematic.piledCount
            if count <= schematic.capacity {
                #expect(piled <= 1)
            } else {
                #expect(piled > 1)
                #expect(piled > previous)
            }
            previous = piled
        }
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
        let cells = schematic.gridCells(
            CGSize(width: 200, height: 120),
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
        #expect(piled.count == schematic.piledCount)
        let origins = piled.map(\.rect.origin.y)
        #expect(Set(origins).count == origins.count)
        // Each reveals the one beneath by exactly the family's
        // offset, so the pile reads the same as Stack's and
        // Track's rather than as a colour.
        for (a, b) in zip(origins, origins.dropFirst()) {
            #expect(b - a == LayoutSchematic.cascadeOffset)
        }
        // The cell count is the window count: nothing is dropped
        // on the way into the pile.
        #expect(cells.count == schematic.ids.count)
    }

    /// The caption may never state dimensions the picture
    /// contradicts — a 6 × 5 caption over a 4 × 4 drawing was the
    /// third arm of #712.
    @Test("a clamped grid says so instead of overstating itself")
    func aClampedGridSaysSo() {
        let clamped = grid(
            columns: 9,
            rows: 9,
            type: .rigid,
            windows: 6
        )
        #expect(clamped.isClamped)
        #expect(
            clamped.cap
                == LayoutSchematic.drawableCells(for: .tile)
        )
        let fits = grid(
            columns: 2,
            rows: 2,
            type: .rigid,
            windows: 6
        )
        #expect(!fits.isClamped)
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
