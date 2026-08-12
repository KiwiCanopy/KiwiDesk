import KiwiDeskCore
import SwiftUI

/// `GridSchematic`'s cell geometry, split out to keep the
/// schematic under the file ceiling (AGENTS.md §2). Pure
/// rect math over the mini canvas; the view side and the
/// capacity rule stay in `GridSchematic.swift`.
extension GridSchematic {
    /// Cell rects for the windows in `ids` (drawn in array order,
    /// mirroring `GridLayout`'s fill: columns-first row-major,
    /// rows-first column-major), plus any trailing empty cell. The
    /// last window spans the leftover when fill-empty-cells is on,
    /// and windows past the grid's capacity — which BOTH types have,
    /// since a dynamic grid balances only up to the same ceiling —
    /// cascade in the last cell.
    func gridCells(
        _ size: CGSize,
        cols: Int,
        rows: Int,
        ids: [Int]
    ) -> [(rect: CGRect, kind: CellKind)] {
        let gap: CGFloat = 3
        let cw = (size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let ch =
            (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        func rect(_ c: Int, _ r: Int, _ cs: Int, _ rs: Int) -> CGRect {
            CGRect(
                x: CGFloat(c) * (cw + gap),
                y: CGFloat(r) * (ch + gap),
                width: cw * CGFloat(cs) + gap * CGFloat(cs - 1),
                height: ch * CGFloat(rs) + gap * CGFloat(rs - 1)
            )
        }
        let capacity = max(1, cols * rows)
        func at(_ i: Int) -> (Int, Int) {
            let slot = min(i, capacity - 1)
            return columnsFirst
                ? (slot % cols, slot / cols)
                : (slot / rows, slot % rows)
        }
        // The engine's OVERFLOW branch lays its tiled prefix out
        // row-major unconditionally — it does not consult
        // `splitDirection` there, unlike its normal fill
        // (`GridLayout.calculateGeometry`). Mirror that rather
        // than the fill order, or a rows-first grid past capacity
        // draws the focus in a cell the engine never puts it in.
        func overflowAt(_ i: Int) -> (Int, Int) {
            (i % cols, i / cols)
        }
        var cells: [(CGRect, CellKind)] = []
        let overflowing = ids.count > capacity
        // Past capacity the engine tiles `capacity - 1` windows
        // and sends the rest to `OverlapStack` in the last cell.
        // Drawing them at one rect is what made the cell darken
        // instead of pile (#712), so each gets its own offset —
        // and `.piled` so it renders opaque.
        let tiled = overflowing ? capacity - 1 : ids.count
        for (i, id) in ids.prefix(tiled).enumerated() {
            let (c, r) = overflowing ? overflowAt(i) : at(i)
            if i == ids.count - 1 && spansLeftover {
                let cs = columnsFirst ? cols - c : 1
                let rs = columnsFirst ? 1 : rows - r
                cells.append((rect(c, r, cs, rs), .window(kind(id))))
            } else {
                cells.append((rect(c, r, 1, 1), .window(kind(id))))
            }
        }
        if overflowing {
            let last = rect(cols - 1, rows - 1, 1, 1)
            cells.append(contentsOf: pileCells(in: last, ids: ids))
        } else if !spansLeftover, ids.count < capacity {
            for i in ids.count..<capacity {
                let (c, r) = at(i)
                cells.append((rect(c, r, 1, 1), .gap))
            }
        }
        return cells
    }

    /// The cascade inside the last cell, **bounded by that cell**.
    ///
    /// A pile whose reveals outrun the cell height marches out of
    /// it and is cut by the canvas clip, so the picture shows
    /// fewer windows than the caption claims — panel scale at
    /// 1 × 6 with twelve windows drew three of them off-canvas.
    /// Only as many tiles as fit are drawn; a `+N` chip on the
    /// front one carries the rest, which is what
    /// `SchematicMoreChip` is for.
    func pileCells(
        in cell: CGRect,
        ids: [Int]
    ) -> [(rect: CGRect, kind: CellKind)] {
        let off = LayoutSchematic.cascadeOffset
        let minTile: CGFloat = 8
        let pile = Array(ids.dropFirst(max(0, ids.count - piledCount)))
        // How many reveals the cell can hold with a legible tile
        // still under them.
        let room = max(
            1,
            Int(((cell.height - minTile) / off).rounded(.down)) + 1
        )
        let drawn = min(pile.count, room)
        let hidden = pile.count - drawn
        let height = max(
            minTile,
            cell.height - off * CGFloat(drawn - 1)
        )
        return pile.suffix(drawn).enumerated().map { k, id in
            (
                CGRect(
                    x: cell.minX,
                    y: cell.minY + CGFloat(k) * off,
                    width: cell.width,
                    height: height
                ),
                CellKind.piled(
                    kind(id),
                    hidden: k == drawn - 1 ? hidden : 0
                )
            )
        }
    }
}
