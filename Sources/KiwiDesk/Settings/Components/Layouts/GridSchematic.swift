import KiwiDeskCore
import SwiftUI

/// The Grid schematic (#125, recount turn 10):
///
/// Both types share one ceiling and both pile past it, which is
/// the engine's own shape (`GridLayout`) and the half a preview
/// most easily omits (#712):
///
/// - **Dynamic** balances the window count into a square-ish
///   grid and stops at the ceiling — Columns first grows a
///   column before a row, Rows first mirrors it. The new window
///   sits where the placement opens it, and fill-empty-space
///   makes the last window span the leftover cell.
/// - **Rigid** fills the ceiling outright, leaving empty cells
///   until the count catches up.
///
/// The ceiling is the configured columns × rows, or
/// `LayoutSchematic.gridAutoSizeCap` when auto-size hands the
/// job to a display this canvas does not have. Past it, the
/// surplus cascades in the last cell — the real behaviour, and
/// exactly what a count the reader can drive is for.
///
/// The two frames the dynamic arm used to draw ("4 windows" →
/// "a 5th opens") retired with the slider: a reader who can add
/// the fifth window themselves does not need it staged, and one
/// frame that answers every count beats two that answer one.
struct GridSchematic: View {
    let columns: Int
    let rows: Int
    let type: GridParams.GridType
    let fillEmptyCells: Bool
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

    /// A window's role in a cell — the three things a *window*
    /// can be. Separate from `CellKind` so that a piled cell can
    /// carry one without `.piled(.gap)` or `.piled(.piled(_))`
    /// being sayable: a gap is the absence of a window and can
    /// never be piled.
    enum TileKind { case tile, focus, new }

    /// What a cell draws. `piled` carries the window's role
    /// rather than replacing it, so a piled window keeps its
    /// identity — the incoming one still shows its `+` when the
    /// placement rule lands it in the pile — plus how many
    /// further windows the pile stands for when the cell could
    /// not hold them all.
    enum CellKind {
        case window(TileKind)
        case gap
        case piled(TileKind, hidden: Int)
    }

    // MARK: - Dimensions, capacity and the pile past it

    /// The cell **ceiling** — the engine's own rule, and only
    /// that. The typed columns × rows, or `gridAutoSizeCap` when
    /// `auto_size` hands the job to a display the canvas does not
    /// have (#712).
    ///
    /// Deliberately NOT clamped to what the canvas can draw. An
    /// earlier cut mined it with a legibility ceiling and so made
    /// the drawn capacity depend on the canvas: rigid 8 × 1 with
    /// five windows drew a two-window pile on the thumbnail and
    /// none in the panel — one config, two pictures, and the
    /// thumbnail's was of an overflow the engine never performs.
    /// The drawing may be clamped; the rule may not.
    var cap: (columns: Int, rows: Int) {
        autoSize
            ? LayoutSchematic.gridAutoSizeCap
            : (columns: max(1, columns), rows: max(1, rows))
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

    /// Windows that do not get a cell of their own.
    ///
    /// Zero until the count actually exceeds capacity: the engine
    /// takes its overflow branch only at `count > capacity`, and
    /// then tiles `capacity - 1` and piles the rest — so the pile
    /// starts one cell early, but only once it starts at all. An
    /// earlier cut dropped the guard and reported one pile at
    /// exactly full, where the drawing correctly piles nothing.
    var piledCount: Int {
        ids.count > capacity ? ids.count - (capacity - 1) : 0
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
        .animation(LayoutSchematic.damping, value: fillEmptyCells)
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
        fillEmptyCells && type == .dynamic
    }

    func kind(_ id: Int) -> TileKind {
        id == newID ? .new : id == focusID ? .focus : .tile
    }

    // MARK: - Cell view + caption / a11y

    @ViewBuilder
    private func cellView(_ kind: CellKind) -> some View {
        switch kind {
        case .gap: SchematicGap()
        case .window(let tile): tileView(tile)
        case .piled(let tile, let hidden):
            ZStack(alignment: .bottomTrailing) {
                SchematicPileTile(
                    active: tile == .focus,
                    isNew: tile == .new
                )
                if hidden > 0 {
                    SchematicMoreChip(hidden: hidden).padding(2)
                }
            }
        }
    }

    @ViewBuilder
    private func tileView(_ tile: TileKind) -> some View {
        switch tile {
        case .tile: SchematicTile()
        case .focus: SchematicTile(active: true)
        case .new: SchematicNewWindow()
        }
    }

    /// Internal so the guard can read it: the captions state the
    /// ceiling in words, and nothing else stops them stating a
    /// different one from the picture — which was two of #712's
    /// three arms (guard-prover, 2026-08-03).
    var caption: String {
        type == .rigid ? rigidCaption : dynamicCaption
    }

    private var rigidCaption: String {
        if autoSize {
            // The numbers come from the stand-in rather than
            // prose, so moving it cannot leave twelve translated
            // captions stating the old one (#712).
            return L(
                "layout.schematic.grid.caption_rigid_auto",
                "A fixed grid sized to your screen (about %1$d × "
                    + "%2$d); each window shrinks to a cell.",
                LayoutSchematic.gridAutoSizeCap.columns,
                LayoutSchematic.gridAutoSizeCap.rows
            )
        }
        return L(
            "layout.schematic.grid.caption_rigid",
            "A fixed %1$d × %2$d grid; each window shrinks to a "
                + "cell, extras stack in the last.",
            cap.columns,
            cap.rows
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
        // A dynamic grid balances only *up to* the same ceiling a
        // rigid one fills, so the ceiling governs it too — the
        // half of the rule the preview used to omit (#712). The
        // numbers are the ceiling itself, never a drawing limit.
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
