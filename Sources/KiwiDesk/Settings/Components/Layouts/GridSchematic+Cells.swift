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
    /// last window spans the leftover when fill-empty-space is on,
    /// and windows past the grid's capacity — which only a rigid
    /// grid has — stack in the last cell, later ones on top.
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
        var cells: [(CGRect, CellKind)] = []
        // Past capacity the engine tiles `capacity - 1` windows
        // and sends the rest to `OverlapStack` in the last cell.
        // Drawing them at one rect is what made the cell darken
        // instead of pile (#712), so each gets its own offset —
        // and `.piled` so it renders opaque.
        let tiled = ids.count > capacity ? capacity - 1 : ids.count
        for (i, id) in ids.prefix(tiled).enumerated() {
            let (c, r) = at(i)
            if i == ids.count - 1 && spansLeftover {
                let cs = columnsFirst ? cols - c : 1
                let rs = columnsFirst ? 1 : rows - r
                cells.append((rect(c, r, cs, rs), kind(id)))
            } else {
                cells.append((rect(c, r, 1, 1), kind(id)))
            }
        }
        if ids.count > capacity {
            let last = rect(cols - 1, rows - 1, 1, 1)
            let pile = Array(ids.dropFirst(tiled))
            let off = LayoutSchematic.cascadeOffset
            let height = max(
                8,
                last.height - off * CGFloat(pile.count - 1)
            )
            for (k, id) in pile.enumerated() {
                cells.append(
                    (
                        CGRect(
                            x: last.minX,
                            y: last.minY + CGFloat(k) * off,
                            width: last.width,
                            height: height
                        ),
                        .piled(kind(id))
                    )
                )
            }
        } else if !spansLeftover, ids.count < capacity {
            for i in ids.count..<capacity {
                let (c, r) = at(i)
                cells.append((rect(c, r, 1, 1), .gap))
            }
        }
        return cells
    }
}
