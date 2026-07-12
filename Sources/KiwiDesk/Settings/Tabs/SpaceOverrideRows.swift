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
            Text(headerCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            modeRows
        }
    }

    private var headerCaption: String {
        L(
            "space_override.caption",
            "Gray = inherit the global value (Layout "
                + "Defaults). Check a box to override "
                + "just that field for this space."
        )
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
        case .track: trackRows
        case .floating:
            placeholder(
                L(
                    "space_override.floating.none",
                    "Floating has no per-space overrides."
                )
            )
        }
    }

    @ViewBuilder
    private var scrollingRows: some View {
        OverridePickerRow(
            label: L("scroll_grid.orientation", "Orientation"),
            value: binding(
                \.scrolling.override,
                space,
                \.orientation
            ),
            global: g.scrolling.orientation,
            options: [
                (.horizontal, L("scroll_grid.horizontal", "Horizontal")),
                (.vertical, L("scroll_grid.vertical", "Vertical")),
            ]
        )
        OverridePickerRow(
            label: L("scroll_grid.focus_anchor", "Focus anchor"),
            value: binding(\.scrolling.override, space, \.anchor),
            global: g.scrolling.anchor,
            options: [
                (.center, L("scroll_grid.anchor.center", "Center")),
                (.left, L("scroll_grid.anchor.left", "Left")),
                (.right, L("scroll_grid.anchor.right", "Right")),
            ]
        )
        placeholder(slotSizePlaceholder)
    }

    private var slotSizePlaceholder: String {
        L(
            "space_override.slot_size_placeholder",
            "Slot size override is Lua/JSON-only for now "
                + "(scroll.set_slot_size)."
        )
    }

    @ViewBuilder
    private var bspRows: some View {
        OverridePickerRow(
            label: L(
                "layout_params.split_strategy",
                "Split strategy"
            ),
            value: binding(\.bsp.override, space, \.strategy),
            global: g.bsp.strategy,
            options: [
                (
                    .shortestSide,
                    L(
                        "layout_params.shortest_side",
                        "Shortest side"
                    )
                ),
                (
                    .alternating,
                    L("layout_params.alternating", "Alternating")
                ),
            ]
        )
        OverrideFractionRow(
            label: L(
                "layout_params.split_ratio_h",
                "Width split ratio"
            ),
            value: binding(\.bsp.override, space, \.splitRatioH),
            global: g.bsp.splitRatioH
        )
        OverrideFractionRow(
            label: L(
                "layout_params.split_ratio_v",
                "Height split ratio"
            ),
            value: binding(\.bsp.override, space, \.splitRatioV),
            global: g.bsp.splitRatioV
        )
    }

    @ViewBuilder
    private var stackRows: some View {
        OverrideStepperRow(
            label: L(
                "layout_params.master_count",
                "Master count"
            ),
            value: binding(
                \.stack.override,
                space,
                \.masterCount
            ),
            global: g.stack.masterCount,
            range: 1...5
        )
        OverrideFractionRow(
            label: L(
                "layout_params.master_ratio",
                "Master ratio"
            ),
            value: binding(
                \.stack.override,
                space,
                \.masterRatio
            ),
            global: g.stack.masterRatio
        )
        OverridePickerRow(
            label: L("layout_params.overflow", "Overflow"),
            value: binding(
                \.stack.override,
                space,
                \.overflowStyle
            ),
            global: g.stack.overflowStyle,
            options: [
                (
                    .cascadeOverflow,
                    L(
                        "layout_params.cascade_overflow",
                        "Cascade overflow"
                    )
                ),
                (
                    .cascadeAll,
                    L(
                        "layout_params.cascade_all",
                        "Cascade all"
                    )
                ),
            ]
        )
    }

    @ViewBuilder
    private var gridRows: some View {
        OverridePickerRow(
            label: L("scroll_grid.grid_type", "Grid type"),
            value: binding(\.grid.override, space, \.type),
            global: g.grid.type,
            options: [
                (.dynamic, L("scroll_grid.dynamic", "Dynamic")),
                (.rigid, L("scroll_grid.rigid", "Rigid")),
            ]
        )
        OverrideToggleRow(
            label: L(
                "scroll_grid.fill_empty_space",
                "Fill empty space"
            ),
            value: binding(
                \.grid.override,
                space,
                \.fillEmptySpace
            ),
            global: g.grid.fillEmptySpace
        )
        OverridePickerRow(
            label: L(
                "scroll_grid.split_direction",
                "Split direction"
            ),
            value: binding(
                \.grid.override,
                space,
                \.splitDirection
            ),
            global: g.grid.splitDirection,
            options: [
                (.horizontal, L("scroll_grid.horizontal", "Horizontal")),
                (.vertical, L("scroll_grid.vertical", "Vertical")),
            ]
        )
        OverrideStepperRow(
            label: L("scroll_grid.columns", "Columns"),
            value: binding(\.grid.override, space, \.columns),
            global: g.grid.columns,
            range: 1...10
        )
        OverrideStepperRow(
            label: L("scroll_grid.rows", "Rows"),
            value: binding(\.grid.override, space, \.rows),
            global: g.grid.rows,
            range: 1...10
        )
    }

    @ViewBuilder
    private var monocleRows: some View {
        OverridePickerRow(
            label: L("scroll_grid.orientation", "Orientation"),
            value: binding(
                \.monocle.override,
                space,
                \.orientation
            ),
            global: g.monocle.orientation,
            options: [
                (.horizontal, L("scroll_grid.horizontal", "Horizontal")),
                (.vertical, L("scroll_grid.vertical", "Vertical")),
            ]
        )
    }

    @ViewBuilder
    private var trackRows: some View {
        OverridePickerRow(
            label: L("track.axis", "Axis"),
            value: binding(\.track.override, space, \.axis),
            global: g.track.axis,
            options: [
                (
                    .vertical,
                    L("track.axis.vertical", "Vertical (columns)")
                ),
                (
                    .horizontal,
                    L("track.axis.horizontal", "Horizontal (rows)")
                ),
            ]
        )
        OverrideStepperRow(
            label: L("track.count", "Track limit"),
            value: binding(\.track.override, space, \.count),
            global: g.track.count,
            range: 0...10
        )
        OverridePickerRow(
            label: L("layout_params.overflow", "Overflow"),
            value: binding(
                \.track.override,
                space,
                \.overflowStyle
            ),
            global: g.track.overflowStyle,
            options: [
                (
                    .cascadeOverflow,
                    L(
                        "layout_params.cascade_overflow",
                        "Cascade overflow"
                    )
                ),
                (
                    .cascadeAll,
                    L(
                        "layout_params.cascade_all",
                        "Cascade all"
                    )
                ),
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
