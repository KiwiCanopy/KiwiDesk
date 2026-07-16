import KiwiDeskCore
import SwiftUI

/// The per-space layout override rows (issue #17): the fields
/// the space's current mode can override, each inheriting the
/// global value (gray) until its checkbox is ticked. Rendered
/// in a space row's "Customize" popover (#68 §3.2, moved out of
/// the inline expander in #205) — the row set mirrors the
/// app-bar override controls, keyed by space instead of layout.
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

    /// Internal (not private) so the Grid/Monocle/Track rows,
    /// which live in `SpaceOverrideRows+ModeRows.swift` to keep
    /// each file under the line ceiling, can read it.
    var g: TilingSettings { model.config.settings }

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
            ],
            style: .menu
        )
        OverridePickerRow(
            label: L("scroll_grid.focus_anchor", "Focus anchor"),
            value: binding(\.scrolling.override, space, \.anchor),
            global: g.scrolling.anchor,
            options: [
                (.center, L("scroll_grid.anchor.center", "Center")),
                (
                    .start,
                    scrollingIsVertical
                        ? L("scroll_grid.anchor.start_v", "Top")
                        : L("scroll_grid.anchor.start_h", "Left")
                ),
                (
                    .end,
                    scrollingIsVertical
                        ? L("scroll_grid.anchor.end_v", "Bottom")
                        : L("scroll_grid.anchor.end_h", "Right")
                ),
                (.follow, L("scroll_grid.anchor.follow", "Follow")),
            ],
            style: .menu
        )
        placeholder(slotSizePlaceholder)
    }

    /// The effective scroll orientation for this space (its
    /// override, else the global), so the anchor labels read
    /// Top/Bottom on a vertical space and Left/Right otherwise —
    /// the value stored stays axis-neutral `start`/`end` (#239).
    private var scrollingIsVertical: Bool {
        g.resolvedScrolling(for: space).orientation == .vertical
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
                    .longestSide,
                    L(
                        "layout_params.longest_side",
                        "Longest side"
                    )
                ),
                (
                    .alternating,
                    L("layout_params.alternating", "Alternating")
                ),
            ],
            style: .menu,
            help: LayoutHelp.splitStrategy
        )
        OverrideFractionRow(
            label: L(
                "layout_params.split_ratio_h",
                "Width split ratio"
            ),
            value: binding(\.bsp.override, space, \.splitRatioH),
            global: g.bsp.splitRatioH,
            help: LayoutHelp.splitRatioH
        )
        OverrideFractionRow(
            label: L(
                "layout_params.split_ratio_v",
                "Height split ratio"
            ),
            value: binding(\.bsp.override, space, \.splitRatioV),
            global: g.bsp.splitRatioV,
            help: LayoutHelp.splitRatioV
        )
    }

    // The Stack rows live in `SpaceOverrideRows+StackRows.swift`
    // (#222 grew them past this file's line budget).

    // MARK: - Binding helper

    /// One generic bridge from an override map's optional field
    /// to a `Binding<T?>`. Setting a field to nil that empties
    /// the override drops the map entry, mirroring the Lua
    /// command. Internal so the mode rows split into
    /// `SpaceOverrideRows+ModeRows.swift` can reach it.
    func binding<O: SpaceLayoutOverride, T>(
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
