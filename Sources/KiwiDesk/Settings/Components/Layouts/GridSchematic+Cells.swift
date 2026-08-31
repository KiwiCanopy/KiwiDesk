import KiwiDeskCore
import SwiftUI

/// Cell layout and geometry math for Grid schematic preview (`GridSchematic`).
extension GridSchematic {
    /// Computes cell rects and kinds for windows in grid layout
    /// (`GridLayout`).
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
        // Mirror engine's row-major overflow layout
        // (`GridLayout.calculateGeometry`).
        func overflowAt(_ i: Int) -> (Int, Int) {
            (i % cols, i / cols)
        }
        var cells: [(CGRect, CellKind)] = []
        let overflowing = ids.count > capacity
        // OverlapStack overflow rendering in last cell (#712).
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

    /// Computes cascading cell stack in last cell
    /// (`LayoutSchematic.cascadeOffset`, `SchematicMoreChip`).
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
