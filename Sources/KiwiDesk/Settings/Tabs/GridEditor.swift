import KiwiDeskCore
import SwiftUI

/// Grid tuning — one mode's tab in Layout Defaults (#204). Split
/// out of the former `ScrollGridEditor`; the schematic (#125)
/// leads the section.
struct GridEditor: View {
    @ObservedObject var model: SettingsModel

    private var grid: Binding<GridParams> {
        $model.config.settings.grid
    }

    var body: some View {
        SettingsSection(
            L("layout.grid.name", "Grid"),
            symbol: LayoutMode.grid.glyph
        ) {
            GridSchematic(
                columns: model.config.settings.grid.columns,
                rows: model.config.settings.grid.rows,
                type: model.config.settings.grid.type,
                fillEmptySpace: model.config.settings.grid
                    .fillEmptySpace,
                autoSize: model.config.settings.grid.autoSize,
                splitDirection: model.config.settings.grid
                    .splitDirection,
                placement: model.config.settings.grid
                    .newWindowPlacement
            )
            SegmentedPicker(
                L("scroll_grid.grid_type", "Grid type"),
                selection: grid.type,
                options: [
                    (
                        L("scroll_grid.dynamic", "Dynamic"),
                        GridParams.GridType.dynamic
                    ),
                    (L("scroll_grid.rigid", "Rigid"), .rigid),
                ]
            )
            // "Arrange: Columns first / Rows first" (#217) — the
            // GUI label only; the Lua/JSON `split_direction`
            // (horizontal/vertical) wire vocabulary is unchanged.
            // "Split direction" read ambiguously (divider-axis vs
            // stack-axis camps); "Columns first / Rows first"
            // names the window arrangement under both models.
            SegmentedPicker(
                L("scroll_grid.arrange", "Arrange"),
                selection: grid.splitDirection,
                options: [
                    (
                        L(
                            "scroll_grid.arrange.columns_first",
                            "Columns first"
                        ),
                        GridParams.SplitDirection.horizontal
                    ),
                    (
                        L(
                            "scroll_grid.arrange.rows_first",
                            "Rows first"
                        ),
                        .vertical
                    ),
                ]
            )
            Divider()
            Toggle(
                L(
                    "scroll_grid.fill_empty_space",
                    "Fill empty space"
                ),
                isOn: grid.fillEmptySpace
            )
            // Fill-empty only applies to dynamic grids; greyed
            // (not hidden) in rigid so its value stays visible
            // (see design-decisions "grey inapplicable controls").
            .disabled(
                model.config.settings.grid.type == .rigid
            )
            gridAutoSize
            StepperRow(
                label: L("scroll_grid.columns", "Columns"),
                value: grid.columns,
                in: 1...10
            )
            .disabled(model.config.settings.grid.autoSize)
            StepperRow(
                label: L("scroll_grid.rows", "Rows"),
                value: grid.rows,
                in: 1...10
            )
            .disabled(model.config.settings.grid.autoSize)
            Divider()
            PlacementPicker(placement: grid.newWindowPlacement)
        }
    }

    /// The auto-size toggle with its caption. A behavior modifier
    /// like Fill empty space / Wrap focus — not a mode switch —
    /// so it reads as a plain toggle; when on it greys the
    /// Columns/Rows steppers below (the screen supplies the dims).
    private var gridAutoSize: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                L("scroll_grid.auto_size", "Auto-size grid"),
                isOn: grid.autoSize
            )
            Text(
                L(
                    "scroll_grid.auto_size_caption",
                    "Fits as many columns and rows as the "
                        + "screen allows, using the minimum "
                        + "window size above."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
