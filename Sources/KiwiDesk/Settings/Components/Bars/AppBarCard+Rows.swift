import KiwiDeskCore
import SwiftUI

/// The App Bar card's row builders, split from
/// `AppBarCard.swift` for the file ceiling. One builder per
/// census row; the Auto/value pairs render at the Auto key as
/// one `AutoGatedGroup`.
extension AppBarCard {
    @ViewBuilder func appBarRow(_ key: AppBarKey) -> some View {
        switch key {
        case .appBarEdge:
            edgeRow
        case .appBarThickness:
            PtSlider(
                label: L("app_bar.thickness", "Thickness"),
                value: style.thickness,
                range: 30...80
            )
        case .appBarGroupAdjacentWindows:
            ToggleRow(
                label: L(
                    "app_bar.group_adjacent",
                    "Group adjacent same-app windows"
                ),
                isOn: style.groupAdjacentWindows,
                help: L(
                    "app_bar.group_adjacent.help",
                    "Merges neighbouring windows of the same app "
                        + "into a single item, marked with a "
                        + "count badge, instead of showing one "
                        + "item each."
                )
            )
        case .appBarBackground:
            SegmentedPicker(
                L(
                    "app_bar.background_style.label",
                    "Background style"
                ),
                selection: style.backgroundStyle,
                options: AppBarOptions.backgroundStyle
                    .map { ($0.1, $0.0) }
            )
        case .appBarLiquidGlass:
            // Hidden, not greyed, below macOS 26 — matching the
            // OS-capability gate (#390) and the census's
            // `.liquidGlassUnavailable` runtime tag.
            if AppBarStyle.glassAvailable {
                ToggleRow(
                    label: L(
                        "app_bar.liquid_glass",
                        "Liquid Glass"
                    ),
                    isOn: style.liquidGlass,
                    help: L(
                        "app_bar.liquid_glass.help",
                        "Lays a translucent glass material over "
                            + "the boxes or the plate. The Fill "
                            + "color tints it, though the tint "
                            + "reads subtle on current macOS."
                    )
                )
            }
        case .appBarBackgroundFit:
            backgroundFitRow
        case .appBarAlignment:
            SegmentedPicker(
                L("app_bar.alignment.label", "Alignment"),
                selection: style.alignment,
                options: AppBarOptions.alignment
                    .map { ($0.1, $0.0) },
                help: L(
                    "app_bar.alignment.label.help",
                    "Where the item group sits along the bar "
                        + "while it fits. Start and End follow "
                        + "the edge (a left bar's Start is its "
                        + "top); once items overflow and scroll, "
                        + "all three behave the same."
                )
            )
        case .appBarActiveIndicator:
            SegmentedPicker(
                L(
                    "app_bar.active_indicator.label",
                    "Active indicator"
                ),
                selection: style.activeIndicator,
                options: AppBarOptions.activeIndicator
                    .map { ($0.1, $0.0) }
            )
        case .appBarContent:
            contentRow
        case .appBarIconSource:
            iconSourceRow
        case .appBarCornerRoundness:
            // Never greyed since background_fit: roundness
            // shapes the Boxed items, the glass plate, AND
            // Plain's own shared plate (BarPlate) — the old
            // Plain grey predated Plain getting a plate
            // (QA 2026-07-19).
            PtSlider(
                label: L(
                    "app_bar.corner_roundness",
                    "Corner roundness"
                ),
                value: style.cornerRoundness,
                range: 0...100,
                unit: "%"
            )
        case .appBarItemSizeAuto:
            AutoGatedGroup(
                title: L("app_bar.item_size.auto", "Auto item size"),
                isOn: AutoSentinel.binding(
                    style.itemSize,
                    restore: 120
                )
            ) {
                PtSlider(
                    label: L("app_bar.item_size", "Item size"),
                    value: style.itemSize,
                    range: 1...200,
                    autoAtZero: true
                )
            }
        case .appBarItemGap:
            PtSlider(
                label: L("app_bar.item_gap", "Item gap"),
                value: style.itemGap,
                range: 0...40
            )
        case .appBarFontSizeAuto:
            AutoGatedGroup(
                title: L("app_bar.font_size.auto", "Auto font size"),
                isOn: AutoSentinel.binding(
                    style.fontSize,
                    restore: 14
                )
            ) {
                PtSlider(
                    label: L("app_bar.font_size", "Font size"),
                    value: style.fontSize,
                    range: 1...32,
                    autoAtZero: true
                )
            }
        case .appBarItemSize, .appBarFontSize:
            // Rendered by their Auto toggles' `AutoGatedGroup`
            // above — the census keeps them as their own gated
            // rows, the GUI composes the pair.
            EmptyView()
        case .appBarDimFactor, .appBarFillColor,
            .appBarHighlightColor, .appBarItemColor,
            .appBarActiveItemColor, .appBarHoverFillColor,
            .appBarHoverItemColor, .appBarGroupBadgeColor,
            .appBarGroupBadgeTextColor:
            // Lua-only or colour-card rows — the render-parity
            // guard keeps them out of this card's order lists.
            EmptyView()
        }
    }

    /// Position plus the shared-edge info row directly under it
    /// (#374) — the Space Bar card shows the same row.
    @ViewBuilder private var edgeRow: some View {
        SegmentedPicker(
            L("app_bar.edge.label", "Position"),
            selection: style.edge,
            options: AppBarOptions.edge.map { ($0.1, $0.0) },
            help: L(
                "app_bar.edge.label.help",
                "Which screen edge the bar occupies. The bar "
                    + "reserves this edge in every layout that "
                    + "shows it."
            )
        )
        if model.config.settings.spaceBarSharesEdgeWithAppBar {
            BarSameEdgeRow(
                edge: model.config.settings.spaceBarStyle.edge
            )
        }
    }

    private var backgroundFitRow: some View {
        SegmentedPicker(
            L(
                "app_bar.background_fit.label",
                "Background size"
            ),
            selection: style.backgroundFit,
            options: AppBarOptions.backgroundFit
                .map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                // Boxed never draws a shared plate to size — so
                // fit is inert for Boxed regardless of the glass
                // finish; Plain (the shipped default, #660)
                // un-greys it. Asked of the bars actually SHOWN,
                // not the global value: a layout overriding to
                // Plain via Lua still reads this global fit, and
                // greying it hid the only editor for a value in
                // use.
                active: gates.everyShownBarBoxed,
                help: L(
                    "app_bar.background_fit.boxed_only",
                    "Boxed draws a box per item, not a shared "
                        + "plate, so there is nothing to size."
                )
            )
        )
    }

    private var contentRow: some View {
        SegmentedPicker(
            L("app_bar.content.label", "Content"),
            selection: style.content,
            options: AppBarOptions.content.map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                // Vertical bars render icon-only (names would
                // need stacked or rotated text) — the stored
                // preference survives an edge round-trip.
                active: gates.everyShownBarVertical,
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
    /// content shows no icons at all. Census-exempt from the
    /// container gate: the ⌃⌥K panel's Apps band reads this
    /// whether or not any bar renders.
    private var iconSourceRow: some View {
        DropdownRow(
            label: L("app_bar.icon_source.label", "App symbol style"),
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
                L("app_bar.icon_source.label", "App symbol style"),
                selection: style.iconSource
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
                active: gates.everyShownBarNameOnly,
                help: L(
                    "app_bar.icon_source.name_only",
                    "Icons are hidden while Content is Name."
                )
            )
        )
    }
}
