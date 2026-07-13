import KiwiDeskCore
import SwiftUI

/// The Grid schematic (#125):
///
/// - **Dynamic** is a two-frame sequence showing how the grid
///   *grows*: four windows balance into a 2×2, then a fifth opens
///   and the grid rebalances — Columns first adds a column (3×2),
///   Rows first adds a row (2×3). The new window sits where the
///   placement opens it (relative to the focused tile), and
///   fill-empty-space makes the last window span the leftover cell.
/// - **Rigid** is a single fixed grid of the configured columns ×
///   rows (or a screen-fit 3×3 when auto-size is on): one full line
///   is filled — a row for Columns first, a column for Rows first —
///   with the focus in the middle and the new window at its
///   placement slot; the rest of the grid stays empty.
struct GridSchematic: View {
    let columns: Int
    let rows: Int
    let type: GridParams.GridType
    let fillEmptySpace: Bool
    let autoSize: Bool
    let splitDirection: GridParams.SplitDirection
    let placement: SpawnPlacement

    private var columnsFirst: Bool {
        splitDirection == .horizontal
    }

    /// The focused window in the dynamic frames (a stable id so it
    /// keeps focus as the grid rebalances).
    private let focusID = 2
    private let newID = 99

    var body: some View {
        if type == .dynamic {
            dynamicPair
        } else {
            SchematicCanvas(caption: caption, axLabel: axLabel) {
                rigidGrid
                    .padding(6)
                    .animation(LayoutSchematic.damping, value: columns)
                    .animation(LayoutSchematic.damping, value: rows)
                    .animation(
                        LayoutSchematic.damping,
                        value: autoSize
                    )
                    .animation(
                        LayoutSchematic.damping,
                        value: splitDirection
                    )
                    .animation(
                        LayoutSchematic.damping,
                        value: placement
                    )
            }
        }
    }

    private enum CellKind { case tile, focus, new, gap }

    // MARK: - Dynamic (two-frame growth)

    private var dynamicPair: some View {
        SchematicPair(
            frameWidth: 118,
            frameHeight: 88,
            firstCaption: L(
                "layout.schematic.grid.dyn_frame_a",
                "4 windows"
            ),
            secondCaption: L(
                "layout.schematic.grid.dyn_frame_b",
                "a 5th opens"
            ),
            caption: dynamicCaption,
            axLabel: axLabel
        ) {
            gridFrame(cols: 2, rows: 2, ids: [1, 2, 3, 4])
        } second: {
            gridFrame(
                cols: columnsFirst ? 3 : 2,
                rows: columnsFirst ? 2 : 3,
                ids: frameBIDs
            )
        }
    }

    /// The five-window array with the new window spliced in per
    /// placement, relative to the focus — the same rule as
    /// `SpaceModel.insert`.
    private var frameBIDs: [Int] {
        var ids = [1, 2, 3, 4]
        let f = ids.firstIndex(of: focusID) ?? 0
        switch placement {
        case .first: ids.insert(newID, at: 0)
        case .last: ids.append(newID)
        case .beforeFocused: ids.insert(newID, at: f)
        case .afterFocused: ids.insert(newID, at: f + 1)
        }
        return ids
    }

    private func gridFrame(
        cols: Int,
        rows: Int,
        ids: [Int]
    ) -> some View {
        GeometryReader { geo in
            let cells = gridCells(
                geo.size,
                cols: cols,
                rows: rows,
                ids: ids
            )
            ZStack(alignment: .topLeading) {
                ForEach(cells.indices, id: \.self) { k in
                    cellView(cells[k].kind)
                        .frame(
                            width: cells[k].rect.width,
                            height: cells[k].rect.height
                        )
                        .position(
                            x: cells[k].rect.midX,
                            y: cells[k].rect.midY
                        )
                }
            }
        }
        .animation(LayoutSchematic.damping, value: fillEmptySpace)
        .animation(LayoutSchematic.damping, value: splitDirection)
        .animation(LayoutSchematic.damping, value: placement)
    }

    /// Cell rects for the windows in `ids` (drawn in array order,
    /// mirroring `GridLayout`'s fill: columns-first row-major,
    /// rows-first column-major), plus any trailing empty cell. The
    /// last window spans the leftover when fill-empty-space is on.
    private func gridCells(
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
        func at(_ i: Int) -> (Int, Int) {
            columnsFirst
                ? (i % cols, i / cols) : (i / rows, i % rows)
        }
        var cells: [(CGRect, CellKind)] = []
        for (i, id) in ids.enumerated() {
            let (c, r) = at(i)
            if i == ids.count - 1 && fillEmptySpace {
                let cs = columnsFirst ? cols - c : 1
                let rs = columnsFirst ? 1 : rows - r
                cells.append((rect(c, r, cs, rs), kind(id)))
            } else {
                cells.append((rect(c, r, 1, 1), kind(id)))
            }
        }
        if !fillEmptySpace {
            for i in ids.count..<(cols * rows) {
                let (c, r) = at(i)
                cells.append((rect(c, r, 1, 1), .gap))
            }
        }
        return cells
    }

    private func kind(_ id: Int) -> CellKind {
        id == newID ? .new : id == focusID ? .focus : .tile
    }

    // MARK: - Rigid (single fixed grid, one line filled)

    /// Auto-size resolves to a screen-fit grid (drawn as 3×3); a
    /// plain rigid grid uses the typed dims, clamped for legibility.
    private var rigidCols: Int { autoSize ? 3 : min(max(columns, 1), 4) }
    private var rigidRows: Int { autoSize ? 3 : min(max(rows, 1), 4) }

    private var rigidGrid: some View {
        let lineCount = columnsFirst ? rigidCols : rigidRows
        let focus = lineCount / 2
        let newIdx = rigidNewIndex(lineCount, focus: focus)
        return VStack(spacing: 3) {
            ForEach(0..<rigidRows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<rigidCols, id: \.self) { col in
                        rigidCell(
                            col: col,
                            row: row,
                            focus: focus,
                            newIdx: newIdx
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rigidCell(
        col: Int,
        row: Int,
        focus: Int,
        newIdx: Int
    ) -> some View {
        let inLine = columnsFirst ? row == 0 : col == 0
        let lineIdx = columnsFirst ? col : row
        if inLine {
            if lineIdx == newIdx {
                SchematicNewWindow()
            } else {
                SchematicTile(active: lineIdx == focus)
            }
        } else {
            emptyCell
        }
    }

    private func rigidNewIndex(_ n: Int, focus: Int) -> Int {
        let raw: Int
        switch placement {
        case .first: raw = 0
        case .last: raw = n - 1
        case .beforeFocused: raw = focus - 1
        case .afterFocused: raw = focus + 1
        }
        return min(max(raw, 0), n - 1)
    }

    private var emptyCell: some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .strokeBorder(
                Color.secondary.opacity(0.2),
                lineWidth: 1
            )
    }

    // MARK: - Cell view + caption / a11y

    @ViewBuilder
    private func cellView(_ kind: CellKind) -> some View {
        switch kind {
        case .tile: SchematicTile()
        case .focus: SchematicTile(active: true)
        case .new: SchematicNewWindow()
        case .gap: SchematicGap()
        }
    }

    private var caption: String {
        type == .rigid ? rigidCaption : dynamicCaption
    }

    private var rigidCaption: String {
        if autoSize {
            return L(
                "layout.schematic.grid.caption_rigid_auto",
                "A fixed grid sized to your screen (about 3 × 3); "
                    + "each window shrinks to a cell."
            )
        }
        return L(
            "layout.schematic.grid.caption_rigid",
            "A fixed %1$d × %2$d grid; each window shrinks to a "
                + "cell, extras stack in the last.",
            columns,
            rows
        )
    }

    private var dynamicCaption: String {
        columnsFirst
            ? L(
                "layout.schematic.grid.order_columns",
                "New windows fill across a row, then wrap down."
            )
            : L(
                "layout.schematic.grid.order_rows",
                "New windows fill down a column, then wrap across."
            )
    }

    private var axLabel: String {
        L(
            "layout.schematic.grid.ax",
            "Grid preview: %1$@.",
            type == .rigid
                ? L("layout.schematic.grid.ax_rigid", "a fixed grid")
                : L(
                    "layout.schematic.grid.ax_dynamic",
                    "a balancing grid"
                )
        )
    }
}
