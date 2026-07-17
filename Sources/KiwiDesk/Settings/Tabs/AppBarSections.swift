import KiwiDeskCore
import SwiftUI

/// The 2-column swatch grid the App Bar color runs share:
/// Global's colors and each layout's per-layout overrides (#2)
/// both wrap their `HexColorField`s in this so the two read as
/// one grid rather than a grid up top and a stacked list below.
/// Flexible columns, so both grids span the pane's full width
/// identically; a row's own label width sets where the swatch
/// sits inside its (equal-width) cell.
struct AppBarColorGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
            ],
            alignment: .leading,
            spacing: 8
        ) {
            content
        }
    }
}

// The App Bar sections are hosted by AppBarSection (#229, its
// own sidebar destination): the global look shared by every
// layout's bar, then a per-layout section for each layout that
// can show one (monocle, scrolling). A layout's checkbox
// toggles its bar on; while on, an accordion exposes per-field
// overrides (unchecked rows inherit the global value shown
// grayed out).

/// The global `app_bar.*` look every layout inherits.
struct GlobalAppBarSection: View {
    @Binding var style: AppBarStyle
    // The full palette is ~10 hex fields; only Box / Active box
    // / Highlight (the ones the preview strip most visibly
    // reflects) stay inline, the rest collapse behind a
    // disclosure shut by default (#229) — the same
    // `advancedExpanded` idiom General/Shortcuts/Monitors use.
    @State private var advancedColorsExpanded = false

    var body: some View {
        SettingsSection(
            L("app_bar.global_style.title", "Global style")
        ) {
            Text(globalStyleCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            // #125 Phase 2: the live mock strip sits above the
            // controls, GapsDiagram-style, so a color/size edit
            // is judged in place before Save.
            AppBarPreviewStrip(style: style)
            behavior
            appearance
        }
        SettingsSection(
            L("app_bar.global_colors.title", "Global colors")
        ) {
            AppBarColorGrid { inlineColors }
            DisclosureGroup(isExpanded: $advancedColorsExpanded) {
                AppBarColorGrid { advancedColors }
                    .padding(.top, 8)
            } label: {
                Text(
                    L(
                        "app_bar.advanced_colors.title",
                        "Advanced colors"
                    )
                )
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder private var behavior: some View {
        SegmentedPicker(
            positionLabel,
            selection: $style.position,
            options: AppBarOptions.position.map { ($0.1, $0.0) },
            help: L(
                "app_bar.position.label.help",
                "Which end of the bar the window tabs pack "
                    + "toward. The concrete edge follows the "
                    + "active layout's axis: Start is the left "
                    + "(or top) edge, End the right (or bottom)."
            )
        )
        SegmentedPicker(
            tabBackgroundLabel,
            selection: $style.tabBackground,
            options: AppBarOptions.tabBackground.map { ($0.1, $0.0) }
        )
        SegmentedPicker(
            activeIndicatorLabel,
            selection: $style.activeIndicator,
            options: AppBarOptions.activeIndicator
                .map { ($0.1, $0.0) }
        )
        SegmentedPicker(
            contentLabel,
            selection: $style.content,
            options: AppBarOptions.content.map { ($0.1, $0.0) }
        )
        // #294 icon rendering, directly below the Content
        // control it depends on; greyed (never hidden, #171)
        // when Name-only content shows no icons at all.
        DropdownRow(
            label: iconSourceLabel,
            help: L(
                "app_bar.icon_source.help",
                "How app icons are drawn. Tinted recolors each "
                    + "icon to match the bar's text colors — "
                    + "Text, Active text, and Hover text in the "
                    + "color settings below — so those colors "
                    + "also decide the icon tint. Glyphs shows "
                    + "a symbol from KiwiDesk's built-in icon "
                    + "set instead, following the same colors; "
                    + "apps without a symbol get a tinted icon."
            )
        ) {
            Picker(
                iconSourceLabel,
                selection: $style.iconSource
            ) {
                ForEach(
                    AppBarOptions.iconSource,
                    id: \.0
                ) { option in
                    Text(option.1).tag(option.0)
                }
            }
        }
        .modifier(
            GreyOut(
                active: style.content == .name,
                help: L(
                    "app_bar.icon_source.name_only",
                    "Icons are hidden while Content is Name."
                )
            )
        )
        // Tinted's brightness, directly below the control that
        // gates it; greyed for the other symbol styles.
        DropdownRow(
            label: tintAppearanceLabel,
            help: L(
                "app_bar.tint_appearance.help",
                "Whether Tinted icons render light or dark. "
                    + "Auto follows the system appearance: "
                    + "light icons in Dark Mode, dark icons in "
                    + "Light Mode."
            )
        ) {
            Picker(
                tintAppearanceLabel,
                selection: $style.tintAppearance
            ) {
                ForEach(
                    AppBarOptions.tintAppearance,
                    id: \.0
                ) { option in
                    Text(option.1).tag(option.0)
                }
            }
        }
        .modifier(
            GreyOut(
                active: style.iconSource != .tintedImage
                    || style.content == .name,
                help: L(
                    "app_bar.tint_appearance.tinted_only",
                    "Applies to the Tinted symbol style."
                )
            )
        )
        ToggleRow(
            label: L(
                "app_bar.group_adjacent",
                "Group adjacent same-app windows"
            ),
            isOn: $style.groupAdjacentWindows,
            help: L(
                "app_bar.group_adjacent.help",
                "Merges neighbouring windows of the same app "
                    + "into a single tab, marked with a count "
                    + "badge, instead of showing one tab each."
            )
        )
    }

    // Ordered thickness → the two Auto-gated size pairs
    // (`AutoGatedGroup`: the toggle bound directly above the slider
    // it owns) → a divider → corner roundness (gated by a different
    // switch, Tab background). "Auto" size/font is a GUI face on the
    // model's 0 = auto sentinel: the toggle greys its slider and
    // stores 0; turning it off restores a sensible non-zero value
    // (#171 grey-out).
    @ViewBuilder private var appearance: some View {
        PtSlider(
            label: L("app_bar.thickness", "Thickness"),
            value: $style.thickness,
            range: 8...80
        )
        AutoGatedGroup(
            title: L("app_bar.item_size.auto", "Auto item size"),
            isOn: AppBarAuto.binding($style.itemSize, restore: 120)
        ) {
            PtSlider(
                label: L("app_bar.item_size", "Item size"),
                value: $style.itemSize,
                range: 0...200
            )
        }
        PtSlider(
            label: L("app_bar.item_gap", "Item gap"),
            value: $style.itemGap,
            range: 0...40
        )
        AutoGatedGroup(
            title: L("app_bar.font_size.auto", "Auto font size"),
            isOn: AppBarAuto.binding($style.fontSize, restore: 14)
        ) {
            PtSlider(
                label: L("app_bar.font_size", "Font size"),
                value: $style.fontSize,
                range: 0...32
            )
        }
        Divider()
        // Roundness only shapes a Boxed tab; grey it for Plain —
        // the "grey, don't hide" convention (#171).
        PtSlider(
            label: L("app_bar.corner_roundness", "Corner roundness"),
            value: $style.cornerRoundness,
            range: 0...100,
            unit: "%"
        )
        .modifier(
            GreyOut(
                active: style.tabBackground != .boxed,
                help: L(
                    "app_bar.corner_roundness.boxed_only",
                    "Corner roundness only applies to Boxed tabs."
                )
            )
        )
    }

    // The three the preview strip reflects most, kept inline.
    @ViewBuilder private var inlineColors: some View {
        HexColorField(
            label: L("app_bar.color.box", "Box"),
            hex: $style.boxColor
        )
        HexColorField(
            label: L("app_bar.color.active_box", "Active box"),
            hex: $style.activeBoxColor
        )
        HexColorField(
            label: L("app_bar.color.highlight", "Highlight"),
            hex: $style.highlightColor
        )
    }

    // The remaining palette, behind the disclosure.
    @ViewBuilder private var advancedColors: some View {
        Group {
            HexColorField(
                label: L("app_bar.color.text", "Text"),
                hex: $style.textColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.active_text",
                    "Active text"
                ),
                hex: $style.activeTextColor
            )
            HexColorField(
                label: L("app_bar.color.hover", "Hover"),
                hex: $style.hoverColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.hover_text",
                    "Hover text"
                ),
                hex: $style.hoverTextColor
            )
        }
        Group {
            HexColorField(
                label: L(
                    "app_bar.color.background",
                    "Background"
                ),
                hex: $style.backgroundColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.group_badge",
                    "Group badge"
                ),
                hex: $style.groupBadgeColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.badge_text",
                    "Badge text"
                ),
                hex: $style.groupBadgeTextColor
            )
        }
    }

    private var globalStyleCaption: String {
        L(
            "app_bar.global_style.caption",
            "Shared by every layout's bar. A layout can "
                + "override any of these below."
        )
    }
    private var positionLabel: String {
        L("app_bar.position.label", "Position")
    }
    private var tabBackgroundLabel: String {
        L("app_bar.tab_background.label", "Tab background")
    }
    private var activeIndicatorLabel: String {
        L("app_bar.active_indicator.label", "Active indicator")
    }
    private var contentLabel: String {
        L("app_bar.content.label", "Content")
    }
    private var iconSourceLabel: String {
        L("app_bar.icon_source.label", "App symbol style")
    }
    private var tintAppearanceLabel: String {
        L("app_bar.tint_appearance.label", "Tint appearance")
    }
}
