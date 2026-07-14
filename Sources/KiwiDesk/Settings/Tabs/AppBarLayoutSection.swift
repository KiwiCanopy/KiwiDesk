import KiwiDeskCore
import SwiftUI

/// One layout's bar: the enable checkbox and, while enabled,
/// the override rows — visible but inherited (#68 §3.4), no
/// accordion: dimmed rows show the global value they inherit,
/// the checkbox unlocks a row, and unlocked rows carry the
/// accent styling from `OverrideChrome`. Split out of
/// `AppBarSections.swift` (which keeps the global editor) to
/// stay under the file-size ceiling.
struct LayoutAppBarSection: View {
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

    @ViewBuilder private var behaviorOverrides: some View {
        OverridePickerRow(
            label: L("app_bar.position.label", "Position"),
            value: $bar.position,
            global: global.position,
            options: AppBarOptions.position
        )
        OverridePickerRow(
            label: L("app_bar.style.label", "Style"),
            value: $bar.style,
            global: global.style,
            options: AppBarOptions.style
        )
        OverridePickerRow(
            label: L("app_bar.active_item.label", "Active item"),
            value: $bar.activeStyle,
            global: global.activeStyle,
            options: AppBarOptions.activeStyle
        )
        OverridePickerRow(
            label: L("app_bar.content.label", "Content"),
            value: $bar.content,
            global: global.content,
            options: AppBarOptions.content
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
        OverrideSliderRow(
            label: L("app_bar.thickness", "Thickness"),
            value: $bar.thickness,
            global: global.thickness,
            range: 8...80
        )
        OverrideSliderRow(
            label: L("app_bar.item_size", "Item size"),
            value: $bar.itemSize,
            global: global.itemSize,
            range: 0...200
        )
        OverrideSliderRow(
            label: L("app_bar.item_gap", "Item gap"),
            value: $bar.itemGap,
            global: global.itemGap,
            range: 0...40
        )
        OverrideSliderRow(
            label: L("app_bar.font_size", "Font size"),
            value: $bar.fontSize,
            global: global.fontSize,
            range: 0...32
        )
        OverrideSliderRow(
            label: L("app_bar.corner_radius", "Corner radius"),
            value: $bar.cornerRadius,
            global: global.cornerRadius,
            range: 0...40
        )
    }
}

/// The color override rows, split out to stay within the view
/// builder's child limit.
struct LayoutAppBarColorOverrides: View {
    @Binding var bar: LayoutAppBar
    let global: AppBarStyle

    var body: some View {
        Group {
            OverrideColorRow(
                label: L("app_bar.color.text", "Text"),
                value: $bar.textColor,
                global: global.textColor
            )
            OverrideColorRow(
                label: L("app_bar.color.box", "Box"),
                value: $bar.boxColor,
                global: global.boxColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.active_text",
                    "Active text"
                ),
                value: $bar.activeTextColor,
                global: global.activeTextColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.active_box",
                    "Active box"
                ),
                value: $bar.activeBoxColor,
                global: global.activeBoxColor
            )
            OverrideColorRow(
                label: L("app_bar.color.highlight", "Highlight"),
                value: $bar.highlightColor,
                global: global.highlightColor
            )
            OverrideColorRow(
                label: L("app_bar.color.hover", "Hover"),
                value: $bar.hoverColor,
                global: global.hoverColor
            )
        }
        Group {
            OverrideColorRow(
                label: L(
                    "app_bar.color.hover_text",
                    "Hover text"
                ),
                value: $bar.hoverTextColor,
                global: global.hoverTextColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.background",
                    "Background"
                ),
                value: $bar.backgroundColor,
                global: global.backgroundColor
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
