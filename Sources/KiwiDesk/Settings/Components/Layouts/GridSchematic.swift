import KiwiDeskCore
import SwiftUI

/// Grid layout visual preview showing dynamic/rigid cell tiling and overflow
/// piles (#125, #712).
struct GridSchematic: View {
    let columns: Int
    let rows: Int
    let type: GridParams.GridType
    let fillEmptyCells: Bool
    let autoSize: Bool
    let splitDirection: GridParams.SplitDirection
    let placement: SpawnPlacement
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Damped animation curve gated on Reduce Motion (#1069).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    var columnsFirst: Bool {
        splitDirection == .horizontal
    }

    /// Stable focus window ID and high sentinel for incoming window (#702).
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
                .animation(damping, value: windows)
                .animation(damping, value: columns)
                .animation(damping, value: rows)
                .animation(damping, value: type)
                .animation(damping, value: autoSize)
                .animation(damping, value: splitDirection)
                .animation(damping, value: placement)
        }
    }

    private var frame: some View {
        gridFrame(
            cols: dims.columns,
            rows: dims.rows,
            ids: ids
        )
    }

    enum TileKind { case tile, focus, new }

    enum CellKind {
        case window(TileKind)
        case gap
        case piled(TileKind, hidden: Int)
    }

    /// Cell ceiling derived from params or auto-size cap (#712).
    var cap: (columns: Int, rows: Int) {
        autoSize
            ? LayoutSchematic.gridAutoSizeCap
            : (columns: max(1, columns), rows: max(1, rows))
    }

    /// Drawn grid dimensions resolved via GridLayout (#712).
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

    var capacity: Int { max(1, dims.columns * dims.rows) }

    /// Number of overflow windows stacked in the last cell.
    var piledCount: Int {
        ids.count > capacity ? ids.count - (capacity - 1) : 0
    }

    /// Window IDs with incoming window spliced via engine placement (#702).
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
        .animation(damping, value: fillEmptyCells)
        .animation(damping, value: splitDirection)
        .animation(damping, value: placement)
    }

    /// Whether last window spans leftover cell in dynamic grid.
    var spansLeftover: Bool {
        fillEmptyCells && type == .dynamic
    }

    func kind(_ id: Int) -> TileKind {
        id == newID ? .new : id == focusID ? .focus : .tile
    }

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

    var caption: String {
        type == .rigid ? rigidCaption : dynamicCaption
    }

    private var rigidCaption: String {
        if autoSize {
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
