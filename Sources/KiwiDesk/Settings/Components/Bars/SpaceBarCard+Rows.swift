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
                // Option names INTERPOLATED from the picker's own
                // keys, not re-typed (#818) — the App Bar twin
                // carries the argument, including why each name
                // appears exactly once.
                help: L(
                    "space_bar.alignment.label.help",
                    "Where the Space items — and the front-app "
                        + "segment, when shown — sit along the "
                        + "bar. \u{201C}%1$@\u{201D} and "
                        + "\u{201C}%2$@\u{201D} follow the edge, "
                        + "so on a left bar the start of the bar "
                        + "is its top.",
                    L("app_bar.alignment.start", "Start"),
                    L("app_bar.alignment.end", "End")
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
            // Lua-only, App-Bar-card, or colour-card rows
            // today. If a census move places one in this
            // card, the render-parity guard forces it into the
            // order lists and it lands here — fail loud in
            // debug rather than render nothing.
            let _ = assertionFailure(
                "unrendered Space Bar census key: \(key.rawValue)"
            )
            EmptyView()
        }
    }
}
