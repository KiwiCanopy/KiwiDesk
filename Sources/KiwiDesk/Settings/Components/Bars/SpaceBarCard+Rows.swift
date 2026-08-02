import KiwiDeskCore
import SwiftUI

/// The Space Bar card's row builders, split from
/// `SpaceBarCard.swift` for the file ceiling. One builder per
/// census row; the Auto/value pairs render at the Auto key as
/// one `AutoGatedGroup` (the value key is that group's slider,
/// so it builds nothing of its own).
extension SpaceBarCard {
    @ViewBuilder func spaceBarRow(_ key: SpaceBarKey) -> some View {
        switch key {
        case .spaceBarEnabled:
            showToggle
        case .spaceBarEdge:
            edgeRow
        case .spaceBarThickness:
            PtSlider(
                label: L("space_bar.thickness", "Thickness"),
                value: style.thickness,
                range: 30...80
            )
        case .spaceBarShowFrontApp:
            ToggleRow(
                label: L(
                    "space_bar.show_front_app",
                    "Show front app"
                ),
                isOn: style.showFrontApp,
                help: L(
                    "space_bar.show_front_app.help",
                    "Adds a trailing segment with the focused "
                        + "window of the Space each display "
                        + "currently shows. Icon-only on vertical "
                        + "bars."
                )
            )
        case .spaceBarHideEmpty:
            ToggleRow(
                label: L(
                    "space_bar.hide_empty",
                    "Hide empty Spaces"
                ),
                isOn: style.hideEmpty,
                help: L(
                    "space_bar.hide_empty.help",
                    "Spaces with no windows are hidden from the "
                        + "bar, except the Space you're currently "
                        + "on. Use a shortcut to jump to a hidden "
                        + "Space."
                )
            )
        case .spaceBarBackground:
            SegmentedPicker(
                L(
                    "space_bar.background_style.label",
                    "Background style"
                ),
                selection: style.backgroundStyle,
                options: AppBarOptions.backgroundStyle
                    .map { ($0.1, $0.0) }
            )
        case .spaceBarLiquidGlass:
            // Offered only where it can render (macOS 26+) —
            // hidden, not greyed, matching the OS-capability
            // gate (#390); the census carries the same rule as
            // its `.liquidGlassUnavailable` runtime tag.
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
        case .spaceBarBackgroundFit:
            backgroundFitRow
        case .spaceBarAlignment:
            SegmentedPicker(
                L("space_bar.alignment.label", "Alignment"),
                selection: style.alignment,
                options: AppBarOptions.alignment
                    .map { ($0.1, $0.0) },
                help: L(
                    "space_bar.alignment.label.help",
                    "Where the Space items — and the front-app "
                        + "segment, when shown — sit along the "
                        + "bar. Start and End follow the edge — a "
                        + "left bar's Start is its top."
                )
            )
        case .spaceBarActiveIndicator:
            SegmentedPicker(
                L(
                    "space_bar.active_indicator.label",
                    "Active indicator"
                ),
                selection: style.activeIndicator,
                // No `.gap` here: an empty slot marking the
                // active Space reads as a missing Space, not a
                // highlight (QA 2026-07-19). The App Bar keeps
                // it (an empty window slot is legible there).
                options: AppBarOptions.activeIndicator
                    .filter { $0.0 != .gap }
                    .map { ($0.1, $0.0) }
            )
        case .spaceBarIconSource:
            iconSourceRow
        case .spaceBarCornerRoundness:
            // Never greyed since background_fit: roundness
            // shapes the Boxed items, the glass plate, AND
            // Plain's own shared plate (BarPlate) — the old
            // Plain grey predated Plain getting a plate
            // (QA 2026-07-19).
            PtSlider(
                label: L(
                    "space_bar.corner_roundness",
                    "Corner roundness"
                ),
                value: style.cornerRoundness,
                range: 0...100,
                unit: "%"
            )
        case .spaceBarItemSizeAuto:
            AutoGatedGroup(
                title: L(
                    "space_bar.item_size.auto",
                    "Auto item size"
                ),
                isOn: AutoSentinel.binding(
                    style.itemSize,
                    restore: 120
                )
            ) {
                PtSlider(
                    label: L("space_bar.item_size", "Item size"),
                    value: style.itemSize,
                    range: 1...200,
                    autoAtZero: true
                )
            }
        case .spaceBarItemGap:
            PtSlider(
                label: L("space_bar.item_gap", "Item gap"),
                value: style.itemGap,
                range: 0...40
            )
        case .spaceBarFontSizeAuto:
            AutoGatedGroup(
                title: L(
                    "space_bar.font_size.auto",
                    "Auto font size"
                ),
                isOn: AutoSentinel.binding(
                    style.fontSize,
                    restore: 14
                )
            ) {
                PtSlider(
                    label: L("space_bar.font_size", "Font size"),
                    value: style.fontSize,
                    range: 1...32,
                    autoAtZero: true
                )
            }
        case .spaceBarGlyphCap:
            glyphCapRow
        case .spaceBarSpringDelay:
            SecondsRow(
                label: L("space_bar.spring_delay", "Spring delay"),
                ms: style.springDelay,
                range: 1.0...4.0,
                help: L(
                    "space_bar.spring_delay.help",
                    "Drag a window onto a Space and hold this "
                        + "long for the view to spring to that "
                        + "Space, so you can drop the window into "
                        + "its layout. A quicker drop moves the "
                        + "window there without switching."
                )
            )
        case .spaceBarItemSize, .spaceBarFontSize:
            // Rendered by their Auto toggles' `AutoGatedGroup`
            // above — the census keeps them as their own gated
            // rows, the GUI composes the pair.
            EmptyView()
        case .spaceBarDimFactor, .spaceBarActiveDimFactor,
            .spaceBarStickyBadge, .copyAppearance,
            .spaceBarItemColor, .spaceBarActiveItemColor,
            .spaceBarFocusedItemColor, .spaceBarFillColor,
            .spaceBarHighlightColor, .spaceBarHoverFillColor,
            .spaceBarHoverItemColor, .spaceBarGroupBadgeColor,
            .spaceBarGroupBadgeTextColor:
            // Lua-only, App-Bar-card, or colour-card rows — the
            // render-parity guard keeps them out of this card's
            // order lists.
            EmptyView()
        }
    }

    /// Coverage-guard write-through (#414): hiding the bar makes
    /// the on-window mark the ONLY sticky cue left, so its
    /// greyed "forced ON" toggle in Appearance must be the real
    /// stored state, not a display fiction. A write-through
    /// BINDING, not .onChange: the set fires only on the user's
    /// gesture, so a profile load that replaces the model's
    /// config while this section is open cannot overwrite a
    /// Lua-authored mark=false (Lua stays unclamped).
    private var showToggle: some View {
        ToggleRow(
            label: L("space_bar.enabled", "Show Space Bar"),
            isOn: Binding(
                get: { style.wrappedValue.enabled },
                set: { on in
                    style.wrappedValue.enabled = on
                    if !on {
                        model.config.settings
                            .stickyStyle.mark = true
                    }
                }
            ),
            help: L(
                "space_bar.enabled.help",
                "One bar per display listing that "
                    + "display's Spaces — click a Space to "
                    + "switch to it. The bar reserves its "
                    + "edge in every layout."
            )
        )
    }

    /// Position plus the shared-edge info row directly under it
    /// (#374) — the App Bar card shows the same row.
    @ViewBuilder private var edgeRow: some View {
        SegmentedPicker(
            L("space_bar.edge.label", "Position"),
            selection: style.edge,
            options: AppBarOptions.edge.map { ($0.1, $0.0) },
            help: L(
                "space_bar.edge.label.help",
                "Which screen edge the Space Bar occupies. "
                    + "Sharing an edge with the App Bar is "
                    + "fine — the two stack."
            )
        )
        if model.config.settings.spaceBarSharesEdgeWithAppBar {
            BarSameEdgeRow(edge: style.wrappedValue.edge)
        }
    }

    private var backgroundFitRow: some View {
        SegmentedPicker(
            L(
                "space_bar.background_fit.label",
                "Background size"
            ),
            selection: style.backgroundFit,
            options: AppBarOptions.backgroundFit
                .map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                // Boxed never draws a shared plate to size —
                // glass hugs each box, solid draws each box — so
                // fit is inert for Boxed regardless of the glass
                // finish. Plain (the shipped default, #660)
                // un-greys it.
                active: style.wrappedValue.backgroundStyle
                    == .boxed,
                help: L(
                    "space_bar.background_fit.boxed_only",
                    "Boxed draws a box per item, not a shared "
                        + "plate, so there is nothing to size."
                )
            )
        )
    }

    private var iconSourceRow: some View {
        DropdownRow(
            label: L(
                "space_bar.icon_source.label",
                "App symbol style"
            ),
            help: L(
                "space_bar.icon_source.help",
                "How app glyphs are drawn. Glyphs shows a "
                    + "monochrome symbol colored by the bar's "
                    + "item colors; apps without a symbol keep "
                    + "their app icon."
            )
        ) {
            Picker(
                L(
                    "space_bar.icon_source.label",
                    "App symbol style"
                ),
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
    }

    /// The stepper plus a neutral live summary of the current
    /// cap — a caption that states what shows, not why (#94
    /// defers the why to `help`). The preview strip is a fixed
    /// stand-in and cannot honestly render N synthetic glyphs,
    /// so the fact lives here.
    @ViewBuilder private var glyphCapRow: some View {
        StepperRow(
            label: L("space_bar.glyph_cap", "Glyphs per Space"),
            value: style.glyphCap,
            in: SpaceBarStyle.glyphCapRange,
            help: L(
                "space_bar.glyph_cap.help",
                "How many app glyphs a Space shows before the "
                    + "rest collapse into a +n badge. Adjacent "
                    + "windows of the same app count as one glyph."
            )
        )
        Text(
            L(
                "space_bar.glyph_cap.summary",
                "Up to %1$d app groups per Space; more collapse "
                    + "into a +n badge.",
                style.wrappedValue.resolvedGlyphCap
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
