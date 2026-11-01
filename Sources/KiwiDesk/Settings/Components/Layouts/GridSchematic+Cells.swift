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
        var cells: [(CGRect, CellKind)] = []
        guard ids.count <= capacity else {
            return scrolledCells(ids, cols: cols, rows: rows) {
                let (c, r) = at($0)
                return rect(c, r, 1, 1)
            }
        }
        for (i, id) in ids.enumerated() {
            let (c, r) = at(i)
            if i == ids.count - 1 && spansLeftover {
                let cs = columnsFirst ? cols - c : 1
                let rs = columnsFirst ? 1 : rows - r
                cells.append((rect(c, r, cs, rs), .window(kind(id))))
            } else {
                cells.append((rect(c, r, 1, 1), .window(kind(id))))
            }
        }
        if !spansLeftover, ids.count < capacity {
            for i in ids.count..<capacity {
                let (c, r) = at(i)
                cells.append((rect(c, r, 1, 1), .gap))
            }
        }
        return cells
    }

    /// A full grid's cells (#2541): every cell before the last
    /// track holds its window, and the rest scroll through that
    /// track as the engine's own run places them (`ZoneRun`), the
    /// incoming window taking the focus; each end that hides
    /// windows counts them. One unit floor per cell over a span of
    /// `line` cells is the fixed grid's run: equal cells, no app
    /// floors to learn.
    func scrolledCells(
        _ ids: [Int],
        cols: Int,
        rows: Int,
        cell: (Int) -> CGRect
    ) -> [(rect: CGRect, kind: CellKind)] {
        let start = GridLayout.runStart(
            columns: cols,
            rows: rows,
            rowMajor: columnsFirst
        )
        let line = columnsFirst ? cols : rows
        var cells = ids.prefix(start).enumerated().map {
            (rect: cell($0.offset), kind: CellKind.window(kind($0.element)))
        }
        let members = Array(ids[start...])
        let run = lastTrackRun(members, line: line)
        let before = run.visible.lowerBound
        let after = members.count - run.visible.upperBound
        for (k, index) in run.visible.enumerated() {
            let hidden =
                (k == 0 ? before : 0)
                + (k == run.visible.count - 1 ? after : 0)
            cells.append(
                (
                    cell(start + k),
                    .scrolled(kind(members[index]), hidden: hidden)
                )
            )
        }
        return cells
    }

    /// The last track's run over its members: one unit floor per
    /// cell over a span of `line` cells, the incoming window taking
    /// the focus.
    func lastTrackRun(_ members: [Int], line: Int) -> ZoneRun {
        ZoneRun.resolve(
            floors: Array(repeating: 1, count: members.count),
            span: CGFloat(line),
            gap: 0,
            head: nil,
            focus: members.firstIndex(of: newID)
        )
    }

    /// A full grid's last-track run as the overflow marks read it
    /// (#2864): every member's rect — a hidden one its edge cell's —
    /// and the track's axis; nil while the grid holds every window.
    func gridRun(
        cells: [(rect: CGRect, kind: CellKind)],
        cols: Int,
        rows: Int,
        ids: [Int]
    ) -> SchematicLaidRun? {
        guard ids.count > max(1, cols * rows) else { return nil }
        let start = GridLayout.runStart(
            columns: cols,
            rows: rows,
            rowMajor: columnsFirst
        )
        let line = columnsFirst ? cols : rows
        let run = lastTrackRun(Array(ids[start...]), line: line)
        let shown = Array(cells[start...].map(\.rect))
        guard let first = shown.first, let last = shown.last else {
            return nil
        }
        let rects = (0..<run.count).map { index -> CGRect in
            if index < run.visible.lowerBound { return first }
            if index >= run.visible.upperBound { return last }
            return shown[index - run.visible.lowerBound]
        }
        return SchematicLaidRun(
            run: run,
            rects: rects,
            vertical: !columnsFirst
        )
    }
}
