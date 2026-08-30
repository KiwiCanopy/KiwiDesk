import KiwiDeskCore
import SwiftUI

/// Per-space layout override rows editor (#17, #678, #68, #205).
struct SpaceOverrideRows: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    /// Armed confirmation dialog for resetting overrides (#290).
    @Binding var pendingResetAll: SpaceID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if mode != .floating {
                    captionRow
                }
                modeRows
            }
            .environment(\.overrideLayoutName, mode.displayName)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(SettingsTheme.sunken)
            )
            footer
        }
    }

    /// Caption and override column header row (2026-08-16).
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(
                    width: SettingsMetrics.overrideStateColumn,
                    alignment: .center
                )
        }
        .padding(.horizontal, SettingsMetrics.overrideRowInset)
    }

    /// Dynamic caption naming the active layout whose defaults an unchecked
    /// row inherits (#290).
    private var caption: String {
        L(
            "space_override.caption",
            "Unchecked settings inherit %1$@ defaults.",
            mode.displayName
        )
    }

    var mode: LayoutMode {
        model.config.spaceModes[space] ?? .bsp
    }

    var g: TilingSettings { model.config.settings }

    /// Census-resolved greying for space override rows and reset action (#678
    /// Phase 3).
    var gates: SpacesGates {
        SpacesGates(settings: g, space: space, mode: mode)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

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
                    "Floating has no per-Space overrides."
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
            options: anchorOptions
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

    /// Every anchor the enum declares, labelled by
    /// `ScrollAnchorLabel` — the same source the Layout Defaults
    /// card's segmented picker reads, so the two offer the same
    /// set without either hand-listing it.
    private var anchorOptions: [(ScrollingParams.Anchor, String)] {
        ScrollingParams.Anchor.allCases.map {
            (
                $0,
                ScrollAnchorLabel.text(
                    for: $0,
                    isVertical: scrollingIsVertical
                )
            )
        }
    }

    /// Effective scroll orientation for space (#239).
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

    /// Generic binding bridge for optional override map fields.
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
