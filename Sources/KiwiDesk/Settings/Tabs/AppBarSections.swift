import KiwiDeskCore
import SwiftUI

// The App Bar sections are hosted by AppearanceSection (#68
// §3.2): the global look shared by every layout's bar, then a
// per-layout section for each layout that can show one
// (monocle, scrolling). A layout's checkbox toggles its bar
// on; while on, an accordion exposes per-field overrides
// (unchecked rows inherit the global value shown grayed out).

/// The global `app_bar.*` look every layout inherits.
struct GlobalAppBarSection: View {
    @Binding var style: AppBarStyle

    var body: some View {
        SettingsSection("Global style") {
            Text(
                "Shared by every layout's bar. A layout can "
                    + "override any of these below."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            behavior
            appearance
        }
        SettingsSection("Global colors") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading),
                ],
                alignment: .leading,
                spacing: 8
            ) {
                colors
            }
        }
    }

    @ViewBuilder private var behavior: some View {
        DropdownRow(label: "Position") {
            Picker("Position", selection: $style.position) {
                ForEach(AppBarOptions.position, id: \.0) {
                    Text($0.1).tag($0.0)
                }
            }
        }
        DropdownRow(label: "Style") {
            Picker("Style", selection: $style.style) {
                ForEach(AppBarOptions.style, id: \.0) {
                    Text($0.1).tag($0.0)
                }
            }
        }
        DropdownRow(label: "Active item") {
            Picker(
                "Active item",
                selection: $style.activeStyle
            ) {
                ForEach(AppBarOptions.activeStyle, id: \.0) {
                    Text($0.1).tag($0.0)
                }
            }
        }
        DropdownRow(label: "Content") {
            Picker("Content", selection: $style.content) {
                ForEach(AppBarOptions.content, id: \.0) {
                    Text($0.1).tag($0.0)
                }
            }
        }
        Toggle(
            "Group adjacent same-app windows",
            isOn: $style.groupAdjacentWindows
        )
    }

    @ViewBuilder private var appearance: some View {
        PtSlider(
            label: "Thickness",
            value: $style.thickness,
            range: 8...80
        )
        PtSlider(
            label: "Item size",
            value: $style.itemSize,
            range: 0...200
        )
        PtSlider(
            label: "Item gap",
            value: $style.itemGap,
            range: 0...40
        )
        PtSlider(
            label: "Font size",
            value: $style.fontSize,
            range: 0...32
        )
        PtSlider(
            label: "Corner radius",
            value: $style.cornerRadius,
            range: 0...40
        )
    }

    @ViewBuilder private var colors: some View {
        Group {
            HexColorField(label: "Text", hex: $style.textColor)
            HexColorField(label: "Box", hex: $style.boxColor)
            HexColorField(
                label: "Active text",
                hex: $style.activeTextColor
            )
            HexColorField(
                label: "Active box",
                hex: $style.activeBoxColor
            )
            HexColorField(
                label: "Highlight",
                hex: $style.highlightColor
            )
            HexColorField(label: "Hover", hex: $style.hoverColor)
        }
        Group {
            HexColorField(
                label: "Hover text",
                hex: $style.hoverTextColor
            )
            HexColorField(
                label: "Background",
                hex: $style.backgroundColor
            )
            HexColorField(
                label: "Group badge",
                hex: $style.groupBadgeColor
            )
            HexColorField(
                label: "Badge text",
                hex: $style.groupBadgeTextColor
            )
        }
    }
}

/// One layout's bar: the enable checkbox and, while enabled,
/// the override rows — visible but inherited (#68 §3.4), no
/// accordion: dimmed rows show the global value they inherit,
/// the checkbox unlocks a row, and unlocked rows carry the
/// accent styling from `OverrideChrome`.
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
        SettingsSection(title + " bar", symbol: mode.glyph) {
            Toggle("Show app bar", isOn: $bar.enabled)
            if bar.enabled {
                DisclosureGroup(
                    "Overrides",
                    isExpanded: $overridesExpanded
                ) {
                    overrides
                }
            }
        }
    }

    /// Split out so `DisclosureGroup` builds it lazily.
    @ViewBuilder private var overrides: some View {
        Text(
            "Dimmed rows inherit the global value — "
                + "tick a box to override just that "
                + "field for this layout."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        behaviorOverrides
        appearanceOverrides
        LayoutAppBarColorOverrides(
            bar: $bar,
            global: global
        )
    }

    @ViewBuilder private var behaviorOverrides: some View {
        OverridePickerRow(
            label: "Position",
            value: $bar.position,
            global: global.position,
            options: AppBarOptions.position
        )
        OverridePickerRow(
            label: "Style",
            value: $bar.style,
            global: global.style,
            options: AppBarOptions.style
        )
        OverridePickerRow(
            label: "Active item",
            value: $bar.activeStyle,
            global: global.activeStyle,
            options: AppBarOptions.activeStyle
        )
        OverridePickerRow(
            label: "Content",
            value: $bar.content,
            global: global.content,
            options: AppBarOptions.content
        )
        OverrideToggleRow(
            label: "Group adjacent same-app windows",
            value: $bar.groupAdjacentWindows,
            global: global.groupAdjacentWindows
        )
    }

    @ViewBuilder private var appearanceOverrides: some View {
        OverrideSliderRow(
            label: "Thickness",
            value: $bar.thickness,
            global: global.thickness,
            range: 8...80
        )
        OverrideSliderRow(
            label: "Item size",
            value: $bar.itemSize,
            global: global.itemSize,
            range: 0...200
        )
        OverrideSliderRow(
            label: "Item gap",
            value: $bar.itemGap,
            global: global.itemGap,
            range: 0...40
        )
        OverrideSliderRow(
            label: "Font size",
            value: $bar.fontSize,
            global: global.fontSize,
            range: 0...32
        )
        OverrideSliderRow(
            label: "Corner radius",
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
                label: "Text",
                value: $bar.textColor,
                global: global.textColor
            )
            OverrideColorRow(
                label: "Box",
                value: $bar.boxColor,
                global: global.boxColor
            )
            OverrideColorRow(
                label: "Active text",
                value: $bar.activeTextColor,
                global: global.activeTextColor
            )
            OverrideColorRow(
                label: "Active box",
                value: $bar.activeBoxColor,
                global: global.activeBoxColor
            )
            OverrideColorRow(
                label: "Highlight",
                value: $bar.highlightColor,
                global: global.highlightColor
            )
            OverrideColorRow(
                label: "Hover",
                value: $bar.hoverColor,
                global: global.hoverColor
            )
        }
        Group {
            OverrideColorRow(
                label: "Hover text",
                value: $bar.hoverTextColor,
                global: global.hoverTextColor
            )
            OverrideColorRow(
                label: "Background",
                value: $bar.backgroundColor,
                global: global.backgroundColor
            )
            OverrideColorRow(
                label: "Group badge",
                value: $bar.groupBadgeColor,
                global: global.groupBadgeColor
            )
            OverrideColorRow(
                label: "Badge text",
                value: $bar.groupBadgeTextColor,
                global: global.groupBadgeTextColor
            )
        }
    }
}
