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
struct GlobalAppBarGroup: View {
    @Binding var style: AppBarStyle
    /// The Space Bar's resolved edge when both enabled bars
    /// share one, else nil (#374) — one optional, so the
    /// illegal "not shared, but has an edge" state can't be
    /// expressed. Kept a plain value: this view stays
    /// model-free. No default on purpose: every call site
    /// must decide, or the row silently vanishes for App Bar
    /// users.
    var spaceBarSharedEdge: AppBarEdge?
    /// Every layout bar that can show one (Monocle, Scrolling),
    /// so a gate can ask whether ANY consumer still reads the
    /// field it guards. No default on purpose, like
    /// `spaceBarSharedEdge`: a call site that forgets this would
    /// silently grey a live control. Predicates live in
    /// `AppBarGroups+Gates.swift`.
    var layoutBars: [LayoutAppBar]
    // The full palette is ~10 hex fields; only Box / Active box
    // / Highlight (the ones the preview strip most visibly
    // reflects) stay inline, the rest collapse behind a
    // disclosure shut by default (#229) — the same
    // `advancedExpanded` idiom General/Shortcuts/Monitors use.
    @State private var advancedColorsExpanded = false

    var body: some View {
        // The header `?` is the gate's live anchor (#527): every
        // help affordance inside the greyed block is dead, so the
        // why-off explanation must live outside it.
        SettingsSection(
            L("app_bar.global_style.title", "Global style"),
            help: anyBarShown ? nil : noBarHelp
        ) {
            Text(globalStyleCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            // #125 Phase 2: the live mock strip sits above the
            // controls, GapsDiagram-style, so a color/size edit
            // is judged in place before Save.
            AppBarPreviewStrip(style: style)
            behavior
                .modifier(
                    GreyOut(active: !anyBarShown, help: noBarHelp)
                )
            // Deliberately OUTSIDE the block gate: `iconSource`
            // has a second consumer that renders whether or not
            // any bar does — the shortcuts panel's Apps band
            // (`ShortcutsPanelController`). A parent `.disabled`
            // would dim a control still governing a visible
            // surface, the mirror of the bug this sweep fixes.
            iconSourceRow
            trailingBehavior
                .modifier(
                    GreyOut(active: !anyBarShown, help: noBarHelp)
                )
            appearance
                .modifier(
                    GreyOut(active: !anyBarShown, help: noBarHelp)
                )
        }
        SettingsSection(
            L("app_bar.global_colors.title", "Global colors"),
            help: anyBarShown ? nil : noBarHelp
        ) {
            AppBarColorGrid { inlineColors }
                .modifier(
                    GreyOut(active: !anyBarShown, help: noBarHelp)
                )
            // The gate sits on the drawer's CONTENT, never on the
            // `DisclosureGroup` — a disabled disclosure refuses to
            // toggle in either direction (owner-confirmed, #527),
            // so gating the whole section left this one stuck in
            // whatever state it was in and hid the colors it
            // holds. The label stays live; the swatches dim.
            DisclosureGroup(isExpanded: $advancedColorsExpanded) {
                AppBarColorGrid { advancedColors }
                    .padding(.top, 8)
                    .modifier(
                        GreyOut(
                            active: !anyBarShown,
                            help: noBarHelp
                        )
                    )
            } label: {
                Text(
                    L("bars.advanced_colors", "Advanced colors")
                )
                .font(.subheadline)
            }
            // Anchored on the label, which is deliberately OUTSIDE
            // the `GreyOut` on the content above — a wash nested in
            // a dimmed subtree compounds to ~0.09 and reads broken.
            .searchTarget(
                L("bars.advanced_colors", "Advanced colors")
            )
        }
    }

    @ViewBuilder private var behavior: some View {
        SegmentedPicker(
            edgeLabel,
            selection: $style.edge,
            options: AppBarOptions.edge.map { ($0.1, $0.0) },
            help: L(
                "app_bar.edge.label.help",
                "Which screen edge the bar occupies. The bar "
                    + "reserves this edge in every layout that "
                    + "shows it."
            )
        )
        if let spaceBarSharedEdge {
            BarSameEdgeRow(edge: spaceBarSharedEdge)
        }
        SegmentedPicker(
            alignmentLabel,
            selection: $style.alignment,
            options: AppBarOptions.alignment
                .map { ($0.1, $0.0) },
            help: L(
                "app_bar.alignment.label.help",
                "Where the item group sits along the bar while "
                    + "it fits. Start and End follow the edge "
                    + "(a left bar's Start is its top); once "
                    + "items overflow and scroll, all three "
                    + "behave the same."
            )
        )
        SegmentedPicker(
            backgroundStyleLabel,
            selection: $style.backgroundStyle,
            options: AppBarOptions.backgroundStyle.map { ($0.1, $0.0) }
        )
        // Liquid Glass is a finish over either shape, offered only
        // where it can render (macOS 26+) — hidden, not greyed,
        // below that, matching the OS-capability gate (#390).
        if AppBarStyle.glassAvailable {
            ToggleRow(
                label: L("app_bar.liquid_glass", "Liquid Glass"),
                isOn: $style.liquidGlass,
                help: L(
                    "app_bar.liquid_glass.help",
                    "Lays a translucent glass material over the "
                        + "boxes or the plate. The Fill color tints "
                        + "it, though the tint reads subtle on "
                        + "current macOS."
                )
            )
        }
        // Directly below the background it sizes (topic
        // grouping); greyed for Boxed, which draws no shared
        // plate (#171).
        SegmentedPicker(
            backgroundFitLabel,
            selection: $style.backgroundFit,
            options: AppBarOptions.backgroundFit
                .map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                // Boxed never draws a shared plate to size — with
                // glass each item hugs its own box, without glass
                // each item draws its own box — so fit is inert for
                // Boxed regardless of the glass finish.
                // Asked of the bars actually SHOWN, not the
                // global value: a layout overriding to Plain
                // still reads this global fit, and greying it
                // hid the only editor for a value in use.
                active: everyShownBarBoxed,
                help: L(
                    "app_bar.background_fit.boxed_only",
                    "Boxed draws a box per item, not a shared "
                        + "plate, so there is nothing to size."
                )
            )
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
        .modifier(
            GreyOut(
                // Vertical bars render icon-only (names would
                // need stacked or rotated text) — the stored
                // preference survives an edge round-trip.
                active: everyShownBarVertical,
                help: L(
                    "app_bar.content.vertical_only",
                    "Left and right bars always show icons "
                        + "only."
                )
            )
        )
    }

    /// #294 icon rendering, directly below the Content control
    /// it depends on; greyed (never hidden, #171) when Name-only
    /// content shows no icons at all. Its own builder so the
    /// editor-wide gate can skip it — see the call site.
    @ViewBuilder private var iconSourceRow: some View {
        DropdownRow(
            label: iconSourceLabel,
            help: L(
                "app_bar.icon_source.help",
                "How app icons are drawn. Glyphs shows a "
                    + "monochrome symbol from KiwiDesk's "
                    + "built-in icon set, colored by the bar's "
                    + "item colors — Item, Active item, and "
                    + "Hover item below — so those colors also "
                    + "decide how the glyphs look. Apps "
                    + "without a symbol keep their app icon."
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
                // Gate on the RENDERED content: a vertical bar
                // collapses Name to icon-only, so icons are on
                // screen and this control must stay live.
                active: everyShownBarNameOnly,
                help: L(
                    "app_bar.icon_source.name_only",
                    "Icons are hidden while Content is Name."
                )
            )
        )
    }

    /// The rows after `iconSourceRow`, so the editor-wide gate
    /// can wrap them without swallowing it.
    @ViewBuilder private var trailingBehavior: some View {
        ToggleRow(
            label: L(
                "app_bar.group_adjacent",
                "Group adjacent same-app windows"
            ),
            isOn: $style.groupAdjacentWindows,
            help: L(
                "app_bar.group_adjacent.help",
                "Merges neighbouring windows of the same app "
                    + "into a single item, marked with a count "
                    + "badge, instead of showing one item each."
            )
        )
    }

    // Color rows live in AppBarGroups+Colors.swift (#374,
    // the SpaceBarColorsGroup sibling split).

    private var globalStyleCaption: String {
        L(
            "app_bar.global_style.caption",
            "The App Bar appears in the layouts that show "
                + "one — Monocle and Scrolling. These settings "
                + "are shared; a layout can override any of "
                + "them below."
        )
    }
    private var edgeLabel: String {
        L("app_bar.edge.label", "Position")
    }
    private var alignmentLabel: String {
        L("app_bar.alignment.label", "Alignment")
    }
    private var backgroundStyleLabel: String {
        L("app_bar.background_style.label", "Background style")
    }
    private var backgroundFitLabel: String {
        L(
            "app_bar.background_fit.label",
            "Background size"
        )
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
}
