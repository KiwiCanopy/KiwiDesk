import KiwiDeskCore
import SwiftUI

/// One layout's bar: the enable checkbox and, while enabled,
/// the override rows — visible but inherited (#68 §3.4), no
/// accordion: dimmed rows show the global value they inherit,
/// the checkbox unlocks a row, and unlocked rows carry the
/// accent styling from `OverrideChrome`. Split out of
/// `AppBarGroups.swift` (which keeps the global editor) to
/// stay under the file-size ceiling.
struct LayoutAppBarGroup: View {
    let title: String
    let mode: LayoutMode
    @Binding var bar: LayoutAppBar
    let global: AppBarStyle
    /// Collapsed by default: the override rows (menu pickers
    /// especially) are the Appearance tab's dominant mount
    /// cost, so a `DisclosureGroup` keeps them unbuilt until
    /// the user opens them — the enable toggle stays outside.
    @State private var overridesExpanded = false

    var body: some View {
        SettingsSection(
            L("app_bar.layout.title", "%1$@ bar", title),
            symbol: mode.glyph
        ) {
            Toggle(
                L("app_bar.layout.show", "Show app bar"),
                isOn: $bar.enabled
            )
            if bar.enabled {
                DisclosureGroup(
                    L("app_bar.layout.overrides", "Overrides"),
                    isExpanded: $overridesExpanded
                ) {
                    overrides
                }
            }
        }
    }

    /// Split out so `DisclosureGroup` builds it lazily.
    @ViewBuilder private var overrides: some View {
        // #125 Phase 2: a compact resolved-state chip leads the
        // rows — swatches of the merged style + how many fields
        // diverge — so the layout's net look reads at a glance
        // without a second mock strip inside the lazy drawer.
        AppBarResolvedStateChip(bar: bar, global: global)
        Text(overridesCaption)
            .font(.caption)
            .foregroundStyle(.secondary)
        behaviorOverrides
        appearanceOverrides
        LayoutAppBarColorOverrides(
            bar: $bar,
            global: global
        )
    }

    private var overridesCaption: String {
        L(
            "app_bar.layout.overrides.caption",
            "Dimmed rows inherit the global value — "
                + "tick a box to override just that "
                + "field for this layout."
        )
    }

    // These override rows deliberately carry no `?` (#251): the
    // global editor above teaches Position/Group-adjacent, and
    // this section sits directly below it behind a collapsed
    // disclosure, so the user has just met the field's help. The
    // override chrome's own `?` slot is for "should I override",
    // not to re-explain the field — reserved for a field the
    // global editor can't already teach.
    //
    // Twin of `GlobalAppBarGroup.behavior` (#291): the same
    // five look fields, rendered here as `.segmented`
    // overrides. Keep the two lists — and their segmented
    // control choice — in lockstep. A sixth field, or a
    // control-type change, must land on both surfaces (same
    // field, same control on comparable full-width surfaces).
    // Convention-guarded, not test-guarded: a missing row or
    // mismatched pill is visible on first glance, not silent
    // data loss, so it doesn't warrant a parity test.
    @ViewBuilder private var behaviorOverrides: some View {
        OverridePickerRow(
            label: L("app_bar.edge.label", "Position"),
            value: $bar.edge,
            global: global.edge,
            options: AppBarOptions.edge,
            style: .segmented
        )
        OverridePickerRow(
            label: L("app_bar.alignment.label", "Alignment"),
            value: $bar.alignment,
            global: global.alignment,
            options: AppBarOptions.alignment,
            style: .segmented
        )
        OverridePickerRow(
            label: L(
                "app_bar.tab_background.label",
                "Tab background"
            ),
            value: $bar.tabBackground,
            global: global.tabBackground,
            options: AppBarOptions.tabBackground,
            style: .segmented
        )
        OverridePickerRow(
            label: L(
                "app_bar.tab_background_fit.label",
                "Background size"
            ),
            value: $bar.tabBackgroundFit,
            global: global.tabBackgroundFit,
            options: AppBarOptions.tabBackgroundFit,
            style: .segmented
        )
        .modifier(
            GreyOut(
                // Boxed never draws a shared plate to size (glass
                // hugs each box, solid draws each box), so fit is
                // inert for Boxed — resolve to see the effective
                // shape under any override.
                active: bar.resolved(with: global)
                    .tabBackground == .boxed,
                help: L(
                    "app_bar.tab_background_fit.boxed_only",
                    "Boxed draws a box per tab, not a shared "
                        + "plate, so there is nothing to size."
                )
            )
        )
        OverridePickerRow(
            label: L(
                "app_bar.active_indicator.label",
                "Active indicator"
            ),
            value: $bar.activeIndicator,
            global: global.activeIndicator,
            options: AppBarOptions.activeIndicator,
            style: .segmented
        )
        OverridePickerRow(
            label: L("app_bar.content.label", "Content"),
            value: $bar.content,
            global: global.content,
            options: AppBarOptions.content,
            style: .segmented
        )
        .modifier(
            GreyOut(
                // Same vertical rule as the global editor,
                // against this layout's EFFECTIVE edge — via
                // the one resolve authority, never a hand
                // mirror of it.
                active: !bar.resolved(with: global)
                    .edge.isHorizontal,
                help: L(
                    "app_bar.content.vertical_only",
                    "Left and right bars always show icons "
                        + "only."
                )
            )
        )
        OverrideToggleRow(
            label: L(
                "app_bar.group_adjacent",
                "Group adjacent same-app windows"
            ),
            value: $bar.groupAdjacentWindows,
            global: global.groupAdjacentWindows
        )
    }

    @ViewBuilder private var appearanceOverrides: some View {
        // Same order as the global editor: thickness → the two
        // Auto-gated size rows (toggle bound above its slider) →
        // divider → corner roundness. An overridden 0 shows as
        // Auto with its slider greyed.
        OverrideSliderRow(
            label: L("app_bar.thickness", "Thickness"),
            value: $bar.thickness,
            global: global.thickness,
            range: 20...80
        )
        OverrideAutoSliderRow(
            label: L("app_bar.box_size", "Box size"),
            autoLabel: L("app_bar.box_size.auto", "Auto box size"),
            value: $bar.boxSize,
            global: global.boxSize,
            restore: 120,
            range: 1...200
        )
        OverrideSliderRow(
            label: L("app_bar.box_gap", "Box gap"),
            value: $bar.boxGap,
            global: global.boxGap,
            range: 0...40
        )
        OverrideAutoSliderRow(
            label: L("app_bar.font_size", "Font size"),
            autoLabel: L("app_bar.font_size.auto", "Auto font size"),
            value: $bar.fontSize,
            global: global.fontSize,
            restore: 14,
            range: 1...32
        )
        Divider()
        // Roundness only shapes a Boxed tab; grey it when this
        // layout resolves to Plain (#171 grey-out).
        OverrideSliderRow(
            label: L(
                "app_bar.corner_roundness",
                "Corner roundness"
            ),
            value: $bar.cornerRoundness,
            global: global.cornerRoundness,
            range: 0...100,
            unit: "%"
        )
        // Never greyed since tab_background_fit: roundness
        // also shapes Plain's own shared plate (matches the
        // global + Space editors, QA 2026-07-19).
    }
}

/// The color override rows, in `AppBarColorGrid` so they read
/// as the same 2-column grid as Global's colors (#2). Field
/// order mirrors the global editor — the inline pair (Fill,
/// Highlight) first, then the rest of the palette — so a field
/// keeps the same reading order in both editors. (Column
/// positions match only for the inline pair: Global splits its
/// colors into an inline grid plus an advanced disclosure, while
/// these eight flow as one continuous grid.)
struct LayoutAppBarColorOverrides: View {
    @Binding var bar: LayoutAppBar
    let global: AppBarStyle

    var body: some View {
        AppBarColorGrid {
            OverrideColorRow(
                label: L("app_bar.color.fill", "Fill"),
                value: $bar.fillColor,
                global: global.fillColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.highlight",
                    "Highlight"
                ),
                value: $bar.highlightColor,
                global: global.highlightColor
            )
            OverrideColorRow(
                label: L("app_bar.color.item", "Item"),
                value: $bar.itemColor,
                global: global.itemColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.active_item",
                    "Active item"
                ),
                value: $bar.activeItemColor,
                global: global.activeItemColor
            )
            OverrideColorRow(
                label: L("app_bar.color.hover_fill", "Hover fill"),
                value: $bar.hoverFillColor,
                global: global.hoverFillColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.hover_item",
                    "Hover item"
                ),
                value: $bar.hoverItemColor,
                global: global.hoverItemColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.group_badge",
                    "Group badge"
                ),
                value: $bar.groupBadgeColor,
                global: global.groupBadgeColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.badge_text",
                    "Badge text"
                ),
                value: $bar.groupBadgeTextColor,
                global: global.groupBadgeTextColor
            )
        }
    }
}
