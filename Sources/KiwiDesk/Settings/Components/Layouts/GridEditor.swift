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

    /// Whether any space's override satisfies `predicate`.
    ///
    /// A control on this GLOBAL editor is inert only when nothing
    /// still reads it — and a per-space override can keep it live
    /// after the global condition would silence it. Asking the
    /// global alone greys a control that is running, the worse of
    /// the two failure directions (#520 wrote the rule one level
    /// down: ask the value that is actually read, never the
    /// global; #527 found this pair still asking the global).
    ///
    /// Deliberately ignores whether that space also overrides the
    /// gated value itself. If it does, the control is inert for
    /// it and we leave it enabled anyway — erring toward enabled
    /// is the safe direction here.
    private func anyOverride(
        _ predicate: (GridOverride) -> Bool
    ) -> Bool {
        model.config.settings.grid.override.values
            .contains(where: predicate)
    }

    /// Fill-empty applies to dynamic grids only, so a rigid
    /// global silences it — unless a space overrides its type
    /// back to dynamic, which makes the global value live again.
    private var fillEmptyIsInert: Bool {
        model.config.settings.grid.type == .rigid
            && !anyOverride { $0.type == .dynamic }
    }

    /// Auto-size supplies the dimensions, so it silences the
    /// Columns/Rows steppers — unless a space overrides auto-size
    /// OFF, which makes the global dimensions live for it.
    private var dimensionsAreInert: Bool {
        model.config.settings.grid.autoSize
            && !anyOverride { $0.autoSize == false }
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.layoutMode(.grid),
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
            // Greyed (not hidden) so its value stays visible (see
            // design-decisions "grey inapplicable controls").
            // `GreyOut`, not a bare `.disabled`, so it dims the
            // same way as its per-space twin — the two used to
            // read differently for the same state (#527). The
            // gating picker sits directly above, so adjacency is
            // the anchor; the hover string names the reason.
            .modifier(
                GreyOut(
                    active: fillEmptyIsInert,
                    help: L(
                        "scroll_grid.fill_empty_space.rigid_only",
                        "A rigid grid keeps every cell, so there "
                            + "is no empty space to fill."
                    )
                )
            )
            Divider()
            // Auto-size + its dimensions read as a distinct block
            // from the grid-fill behaviour above, mirroring the
            // Divider BSP/Stack put before their own such content.
            gridDimensions
            Divider()
            PlacementPicker(placement: grid.newWindowPlacement)
        }
    }

    /// The Auto-size toggle gating the Columns/Rows steppers, via
    /// the shared `AutoGatedGroup` (#233). A behaviour modifier
    /// like Fill empty space / Wrap focus — not a mode switch — so
    /// it reads as a plain toggle; on, it greys the steppers
    /// (visible but disabled, #171), the screen supplying the dims.
    private var gridDimensions: some View {
        AutoGatedGroup(
            title: L("scroll_grid.auto_size", "Auto-size grid"),
            isOn: grid.autoSize,
            caption: L(
                "scroll_grid.auto_size_caption",
                "Fits as many columns and rows as the "
                    + "screen allows, using the minimum "
                    + "window size above."
            ),
            gatedIsInert: dimensionsAreInert
        ) {
            StepperRow(
                label: L("scroll_grid.columns", "Columns"),
                value: grid.columns,
                in: 1...10
            )
            StepperRow(
                label: L("scroll_grid.rows", "Rows"),
                value: grid.rows,
                in: 1...10
            )
        }
    }
}
