import KiwiDeskCore
import SwiftUI

/// The per-space layout override rows (issue #17): the fields
/// the space's current mode can override, each inheriting the
/// global value (gray) until its checkbox is ticked. Rendered
/// inline inside a space row's "Customize" expander (#68 §3.2)
/// — the row set mirrors the app-bar override controls, keyed
/// by space instead of layout.
struct SpaceOverrideRows: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                "Gray = inherit the global value (Layout "
                    + "Defaults). Check a box to override "
                    + "just that field for this space."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            modeRows
        }
    }

    private var mode: LayoutMode {
        model.config.spaceModes[space] ?? .bsp
    }

    private var g: TilingSettings { model.config.settings }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Per-mode rows

    @ViewBuilder
    private var modeRows: some View {
        switch mode {
        case .scrolling: scrollingRows
        case .bsp: bspRows
        case .stack: stackRows
        case .grid: gridRows
        case .monocle: monocleRows
        case .floating:
            placeholder(
                "Floating has no per-space overrides."
            )
        }
    }

    @ViewBuilder
    private var scrollingRows: some View {
        OverridePickerRow(
            label: "Orientation",
            value: binding(
                \.scrolling.override,
                space,
                \.orientation
            ),
            global: g.scrolling.orientation,
            options: [
                (.horizontal, "Horizontal"),
                (.vertical, "Vertical"),
            ]
        )
        OverridePickerRow(
            label: "Focused anchor",
            value: binding(\.scrolling.override, space, \.anchor),
            global: g.scrolling.anchor,
            options: [
                (.center, "Center"), (.left, "Left"),
                (.right, "Right"),
            ]
        )
        placeholder(
            "Slot size override is Lua/JSON-only for now "
                + "(scroll.set_slot_size)."
        )
    }

    @ViewBuilder
    private var bspRows: some View {
        OverridePickerRow(
            label: "Split strategy",
            value: binding(\.bsp.override, space, \.strategy),
            global: g.bsp.strategy,
            options: [
                (.shortestSide, "Shortest side"),
                (.alternating, "Alternating"),
            ]
        )
        OverrideFractionRow(
            label: "Split ratio",
            value: binding(\.bsp.override, space, \.splitRatio),
            global: g.bsp.splitRatio
        )
    }

    @ViewBuilder
    private var stackRows: some View {
        OverrideStepperRow(
            label: "Master count",
            value: binding(
                \.stack.override,
                space,
                \.masterCount
            ),
            global: g.stack.masterCount,
            range: 1...5
        )
        OverrideFractionRow(
            label: "Master ratio",
            value: binding(
                \.stack.override,
                space,
                \.masterRatio
            ),
            global: g.stack.masterRatio
        )
        OverridePickerRow(
            label: "Overflow",
            value: binding(
                \.stack.override,
                space,
                \.overflowStyle
            ),
            global: g.stack.overflowStyle,
            options: [
                (.cascadeOverflow, "Cascade overflow"),
                (.cascadeAll, "Cascade all"),
            ]
        )
    }

    @ViewBuilder
    private var gridRows: some View {
        OverridePickerRow(
            label: "Grid type",
            value: binding(\.grid.override, space, \.type),
            global: g.grid.type,
            options: [(.dynamic, "Dynamic"), (.rigid, "Rigid")]
        )
        OverrideToggleRow(
            label: "Fill empty space",
            value: binding(
                \.grid.override,
                space,
                \.fillEmptySpace
            ),
            global: g.grid.fillEmptySpace
        )
        OverridePickerRow(
            label: "Split direction",
            value: binding(
                \.grid.override,
                space,
                \.splitDirection
            ),
            global: g.grid.splitDirection,
            options: [
                (.horizontal, "Horizontal"),
                (.vertical, "Vertical"),
            ]
        )
        OverrideStepperRow(
            label: "Columns",
            value: binding(\.grid.override, space, \.columns),
            global: g.grid.columns,
            range: 1...10
        )
        OverrideStepperRow(
            label: "Rows",
            value: binding(\.grid.override, space, \.rows),
            global: g.grid.rows,
            range: 1...10
        )
    }

    @ViewBuilder
    private var monocleRows: some View {
        OverridePickerRow(
            label: "Orientation",
            value: binding(
                \.monocle.override,
                space,
                \.orientation
            ),
            global: g.monocle.orientation,
            options: [
                (.horizontal, "Horizontal"),
                (.vertical, "Vertical"),
            ]
        )
    }

    // MARK: - Binding helper

    /// One generic bridge from an override map's optional field
    /// to a `Binding<T?>`. Setting a field to nil that empties
    /// the override drops the map entry, mirroring the Lua
    /// command.
    private func binding<O: SpaceLayoutOverride, T>(
        _ map: WritableKeyPath<TilingSettings, [SpaceID: O]>,
        _ space: SpaceID,
        _ field: WritableKeyPath<O, T?>
    ) -> Binding<T?> {
        Binding(
            get: {
                model.config.settings[keyPath: map][space]?[
                    keyPath: field
                ]
            },
            set: { v in
                var o =
                    model.config.settings[keyPath: map][space]
                    ?? O()
                o[keyPath: field] = v
                model.config.settings[keyPath: map][space] =
                    o.isEmpty ? nil : o
            }
        )
    }
}
