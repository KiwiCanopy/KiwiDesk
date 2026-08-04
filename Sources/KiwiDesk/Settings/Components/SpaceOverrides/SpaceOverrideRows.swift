import KiwiDeskCore
import SwiftUI

/// The per-space layout override rows (issue #17): the fields
/// the space's current mode can override, each inheriting the
/// global value (gray) until its checkbox is ticked. Rendered in
/// the pushed per-space override editor (#678 8b,
/// `SpacesSection+Overrides.swift`; an inline expander in #68
/// §3.2, then a Customize popover in #205 before the pane) — the
/// row set mirrors the app-bar override controls, keyed by space
/// instead of layout.
struct SpaceOverrideRows: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    /// Set by the `Reset All Layout Overrides` button to arm the
    /// confirmation dialog (#290). The dialog lives on
    /// `SpacesSection`, not here, so it survives the popover
    /// dismissing — this row set only requests it.
    @Binding var pendingResetAll: SpaceID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                // Floating has no override rows, only the placeholder
                // below, so it carries no caption or column header —
                // an "inherit Floating defaults" caption over "has no
                // overrides" contradicts itself.
                if mode != .floating {
                    captionRow
                }
                modeRows
            }
            // The active layout's name, read by every `OverrideChrome`
            // below to render "follows <Layout> defaults · <value>"
            // on an inheriting row (#678 8b).
            .environment(\.overrideLayoutName, mode.displayName)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.35))
            )
            footer
        }
    }

    /// The caption and the "OVERRIDE" column header aligned over
    /// the rows' trailing checkboxes. Only drawn for a tiling
    /// layout (the caller gates Floating out).
    private var captionRow: some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: SettingsMetrics.overrideRowInset
        ) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: SettingsMetrics.overrideRowInset)
            Text(L("space_override.override_column", "Override"))
                .font(.caption2)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
                .frame(
                    width: SettingsMetrics.overrideStateColumn,
                    alignment: .center
                )
        }
        .padding(.horizontal, SettingsMetrics.overrideRowInset)
    }

    /// Dynamic caption naming the active layout whose defaults an
    /// unchecked row inherits (#290), replacing the old generic
    /// "gray = inherit" gloss.
    private var caption: String {
        L(
            "space_override.caption",
            "Unchecked settings inherit %1$@ defaults.",
            mode.displayName
        )
    }

    /// Internal so the footer extension
    /// (`SpaceOverrideRows+Footer.swift`) can read the active
    /// layout for its reset label and dormant filter.
    var mode: LayoutMode {
        model.config.spaceModes[space] ?? .bsp
    }

    /// Internal (not private) so the Grid/Monocle/Track rows,
    /// which live in `SpaceOverrideRows+ModeRows.swift` to keep
    /// each file under the line ceiling, can read it.
    var g: TilingSettings { model.config.settings }

    /// The census-resolved greying for this space's override rows
    /// and reset action (#678 Phase 3). One per-instance resolver,
    /// keyed on the space and its active layout, so a row never
    /// re-derives "is this space rigid / auto-sized" beside the
    /// gate that declares it. Internal so the mode-row and footer
    /// extensions consult the same instance.
    var gates: SpacesGates {
        SpacesGates(settings: g, space: space, mode: mode)
    }

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
            ]
        )
        OverrideSlotSizeRow(
            model: model,
            isVertical: scrollingIsVertical,
            value: binding(\.scrolling.override, space, \.slotSize),
            // The inherited value is the global slot size (the
            // per-space override is the only layer above it), so
            // unchecked shows it and checking seeds it — no jump.
            global: g.scrolling.slotSize
        )
    }

    /// The effective scroll orientation for this space (its
    /// override, else the global), so the slot-size and anchor
    /// labels read Row height / Top-Bottom on a vertical space and
    /// Column width / Left-Right otherwise — the values stored
    /// stay axis-neutral (`start`/`end`, `ScrollSize`) (#239).
    private var scrollingIsVertical: Bool {
        g.resolvedScrolling(for: space).orientation == .vertical
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
