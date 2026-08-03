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

    var columnsFirst: Bool {
        splitDirection == .horizontal
    }

    /// The focused window — a stable id so it keeps focus as the
    /// grid rebalances — and the incoming one, which sorts above
    /// every established id at any count.
    ///
    /// The focus falls back to the single established window
    /// where the count leaves no second one, so the relative
    /// placements keep a reference. Pinned at 2, they had none at
    /// two windows and the grid drew a `+` beside nothing (#702).
    var focusID: Int { min(2, max(1, windows - 1)) }
    let newID = 9_999

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

    private var frame: some View {
        gridFrame(
            cols: dims.columns,
            rows: dims.rows,
            ids: ids
        )
    }

    /// What a cell draws. `piled` wraps another kind rather than
    /// replacing it, so a piled window keeps its identity — the
    /// incoming one still carries its `+` when it lands in the
    /// pile, which is where the placement rule often puts it.
    indirect enum CellKind {
        case tile, focus, new, gap
        case piled(CellKind)
    }

    // MARK: - Dimensions, capacity and the pile past it

    /// The cell **ceiling**, the engine's own notion: the typed
    /// columns × rows, or a stand-in when `auto_size` hands the
    /// job to the screen (#712).
    ///
    /// Auto-size is the only arm that needs standing in for.
    /// `GridLayout.capDimensions` fits as many minimum-size cells
    /// as the display allows, and this canvas is not a display and
    /// has no minimum window size — so it cannot judge how many
    /// windows fit and does not pretend to. With auto-size off the
    /// ceiling is the user's own setting, sitting in the two
    /// steppers right above this preview.
    ///
    /// Clamped to what the canvas can legibly draw, so the picture
    /// and the caption cannot disagree: `drawableCells` is the
    /// picture's limit, this is the layout's rule, and they are
    /// two different ceilings.
    var cap: (columns: Int, rows: Int) {
        let drawable = LayoutSchematic.drawableCells(for: scale)
        let ceiling =
            autoSize
            ? LayoutSchematic.autoSizeCap
            : (columns: max(1, columns), rows: max(1, rows))
        return (
            min(ceiling.columns, drawable.columns),
            min(ceiling.rows, drawable.rows)
        )
    }

    /// Whether the canvas drew a smaller grid than the ceiling
    /// asks for, so the caption can say so instead of stating
    /// dimensions the picture contradicts (#712).
    var isClamped: Bool {
        !autoSize
            && (max(1, columns) > cap.columns
                || max(1, rows) > cap.rows)
    }

    /// The drawn dimensions — the engine's whole rule, not just
    /// its balance. Rigid takes the ceiling verbatim; dynamic
    /// balances *up to* it and stops, which is the behaviour the
    /// preview used to omit: it called `balanced` alone and so
    /// kept subdividing forever as the count rose (#712).
    var dims: (columns: Int, rows: Int) {
        var params = GridParams()
        params.type = type
        params.splitDirection = splitDirection
        return GridLayout.dimensions(
            count: ids.count,
            params: params,
            cap: cap
        )
    }

    /// Cells the drawn grid holds. Windows past it pile in the
    /// last one, exactly as `GridLayout` sends them to
    /// `OverlapStack`.
    var capacity: Int { max(1, dims.columns * dims.rows) }

    /// Windows that do not get a cell of their own. The engine
    /// tiles `capacity - 1` and piles the rest, so the pile
    /// starts one cell early.
    var piledCount: Int {
        max(0, ids.count - (capacity - 1))
    }

    /// The window array with the new window spliced in where
    /// `placement` opens it, asked of the engine through
    /// `SchematicPlacement` rather than reproduced here (#702).
    /// Cells are keyed by id, so the focus follows its window
    /// when the splice pushes it along.
    var ids: [Int] {
        var ids = Array(1...max(1, windows - 1))
        let index = SchematicPlacement.splice(
            placement,
            count: ids.count,
            focus: ids.firstIndex(of: focusID) ?? 0
        ).incoming
        ids.insert(newID, at: index)
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
    var spansLeftover: Bool {
        fillEmptySpace && type == .dynamic
    }

    func kind(_ id: Int) -> CellKind {
        id == newID ? .new : id == focusID ? .focus : .tile
    }

    // MARK: - Cell view + caption / a11y

    @ViewBuilder
    private func cellView(_ kind: CellKind) -> some View {
        switch kind {
        case .tile: SchematicTile()
        case .focus: SchematicTile(active: true)
        case .new: SchematicNewWindow()
        case .gap: SchematicGap()
        case .piled(let inner):
            SchematicPileTile(
                active: isFocus(inner),
                isNew: isNew(inner)
            )
        }
    }

    private func isFocus(_ kind: CellKind) -> Bool {
        if case .focus = kind { return true }
        return false
    }

    private func isNew(_ kind: CellKind) -> Bool {
        if case .new = kind { return true }
        return false
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
        if isClamped {
            // Never state dimensions the picture contradicts: at
            // 6 × 5 the caption used to promise thirty cells over
            // a sixteen-cell drawing (#712).
            return L(
                "layout.schematic.grid.caption_rigid_clamped",
                "A fixed %1$d × %2$d grid; each window shrinks to "
                    + "a cell, extras stack in the last. Shown "
                    + "smaller here (%3$d × %4$d) to stay legible.",
                columns,
                rows,
                cap.columns,
                cap.rows
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
        let order =
            columnsFirst
            ? L(
                "layout.schematic.grid.order_columns",
                "New windows fill across a row, then wrap down."
            )
            : L(
                "layout.schematic.grid.order_rows",
                "New windows fill down a column, then wrap across."
            )
        guard !autoSize else { return order }
        // A dynamic grid balances only *up to* the same ceiling a
        // rigid one fills, so the typed dimensions govern it too
        // — the half of the rule the preview used to omit (#712).
        return L(
            "layout.schematic.grid.order_capped",
            "%1$@ It balances up to %2$d × %3$d, then the surplus "
                + "stacks in the last cell.",
            order,
            cap.columns,
            cap.rows
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
