import KiwiDeskCore
import SwiftUI

/// The Grid schematic (#125, recount turn 10):
///
/// - **Dynamic** balances the window count into a square-ish
///   grid through the engine's own `GridLayout.balanced`, so the
///   preview rebalances as the count slider moves — Columns
///   first grows a column before a row, Rows first mirrors it.
///   The new window sits where the placement opens it (relative
///   to the focused tile), and fill-empty-space makes the last
///   window span the leftover cell.
/// - **Rigid** is a fixed grid of the configured columns × rows
///   (or a screen-fit 3×3 when auto-size is on) filled in the
///   engine's fill order; cells past the window count stay
///   empty, and a count past the grid's capacity stacks its
///   surplus in the last cell — the real behaviour, which is
///   exactly what a count the reader can drive is for.
///
/// The two frames the dynamic arm used to draw ("4 windows" →
/// "a 5th opens") retired with the slider: a reader who can add
/// the fifth window themselves does not need it staged, and one
/// frame that answers every count beats two that answer one.
struct GridSchematic: View {
    let columns: Int
    let rows: Int
    let type: GridParams.GridType
    let fillEmptySpace: Bool
    let autoSize: Bool
    let splitDirection: GridParams.SplitDirection
    let placement: SpawnPlacement
    /// Windows on screen, the incoming one included.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    private var columnsFirst: Bool {
        splitDirection == .horizontal
    }

    /// The focused window (a stable id so it keeps focus as the
    /// grid rebalances) and the incoming one, which sorts above
    /// every established id at any count.
    private let focusID = 2
    private let newID = 9_999

    var body: some View {
        SchematicCanvas(
            width: scale.width,
            height: scale.height,
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            frame
                .padding(6)
                .animation(LayoutSchematic.damping, value: windows)
                .animation(LayoutSchematic.damping, value: columns)
                .animation(LayoutSchematic.damping, value: rows)
                .animation(LayoutSchematic.damping, value: type)
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

    @ViewBuilder
    private var frame: some View {
        if type == .dynamic {
            gridFrame(
                cols: dynamicDims.columns,
                rows: dynamicDims.rows,
                ids: ids
            )
        } else {
            rigidGrid
        }
    }

    private enum CellKind { case tile, focus, new, gap }

    // MARK: - Dynamic (balanced against the count)

    /// The engine's own balance for this count — called rather
    /// than reproduced, so a change to how KiwiDesk balances a
    /// dynamic grid moves the preview with it. Uncapped on
    /// purpose: the cap is a function of the real screen and the
    /// minimum window size, and this canvas is neither.
    var dynamicDims: (columns: Int, rows: Int) {
        GridLayout.balanced(
            count: ids.count,
            splitDirection: splitDirection
        )
    }

    /// The window array with the new window spliced in per
    /// placement, relative to the focus — the same rule as
    /// `SpaceModel.insert`.
    var ids: [Int] {
        var ids = Array(1...max(1, windows - 1))
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

    /// Whether the last window spans the leftover cell. Only a
    /// dynamic grid has leftovers to absorb — the same rule the
    /// row itself greys on (`LayoutDefaultsGates.fillEmptyIsInert`
    /// asks the resolved type, since a space may override it) —
    /// so the rigid arm draws its empty cells whatever the toggle
    /// says, which is the behaviour the toggle's grey describes.
    private var spansLeftover: Bool {
        fillEmptySpace && type == .dynamic
    }

    /// Cell rects for the windows in `ids` (drawn in array order,
    /// mirroring `GridLayout`'s fill: columns-first row-major,
    /// rows-first column-major), plus any trailing empty cell. The
    /// last window spans the leftover when fill-empty-space is on,
    /// and windows past the grid's capacity — which only a rigid
    /// grid has — stack in the last cell, later ones on top.
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
        let capacity = max(1, cols * rows)
        func at(_ i: Int) -> (Int, Int) {
            let slot = min(i, capacity - 1)
            return columnsFirst
                ? (slot % cols, slot / cols)
                : (slot / rows, slot % rows)
        }
        var cells: [(CGRect, CellKind)] = []
        for (i, id) in ids.enumerated() {
            let (c, r) = at(i)
            if i == ids.count - 1 && spansLeftover {
                let cs = columnsFirst ? cols - c : 1
                let rs = columnsFirst ? 1 : rows - r
                cells.append((rect(c, r, cs, rs), kind(id)))
            } else {
                cells.append((rect(c, r, 1, 1), kind(id)))
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

    private func kind(_ id: Int) -> CellKind {
        id == newID ? .new : id == focusID ? .focus : .tile
    }

    // MARK: - Rigid (a fixed grid the count fills)

    /// Auto-size resolves to a screen-fit grid (drawn as 3×3); a
    /// plain rigid grid uses the typed dims, clamped for legibility.
    private var rigidCols: Int { autoSize ? 3 : min(max(columns, 1), 4) }
    private var rigidRows: Int { autoSize ? 3 : min(max(rows, 1), 4) }

    private var rigidGrid: some View {
        gridFrame(cols: rigidCols, rows: rigidRows, ids: ids)
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
