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
        case .spaceBarShowFrontApp:
            VStack(alignment: .leading, spacing: 3) {
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
                            + "currently shows. Icon-only on "
                            + "vertical bars."
                    )
                )
                Text(
                    L(
                        "space_bar.show_front_app.caption",
                        "Shows only on a Space without an App Bar — "
                            + "the App Bar already marks the focused "
                            + "window."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)
            }
        case .spaceBarGroupAdjacent:
            ToggleRow(
                label: L(
                    "space_bar.group_adjacent",
                    "Group adjacent same-app windows"
                ),
                isOn: style.groupAdjacentWindows,
                help: L(
                    "space_bar.group_adjacent.help",
                    "Merges neighbouring windows of the same app "
                        + "in a Space into one glyph with a count "
                        + "badge, instead of one glyph each."
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
        case .spaceBarActiveIndicator:
            SegmentedPicker(
                L(
                    "space_bar.active_indicator.label",
                    "Active indicator"
                ),
                selection: style.activeIndicator,
                options: AppBarOptions.activeIndicator
                    .map { ($0.1, $0.0) }
            )
        case .spaceBarInactiveContent:
            SegmentedPicker(
                L("space_bar.inactive_content", "Other Spaces"),
                selection: style.inactiveContent,
                options: AppBarOptions.inactiveContent
                    .map { ($0.1, $0.0) },
                help: inactiveContentHelp
            )
        case .spaceBarItemLabel:
            SegmentedPicker(
                L("space_bar.item_label", "Space label"),
                selection: style.itemLabel,
                options: AppBarOptions.itemLabel
                    .map { ($0.1, $0.0) },
                help: itemLabelHelp
            )
        case .spaceBarGlyphSpan:
            glyphSpanRow
        case .spaceBarGlyphGap:
            PtSlider(
                label: L("space_bar.glyph_gap", "Glyph gap"),
                value: style.glyphGap,
                range: BarSliderBands.glyphGap,
                help: L(
                    "space_bar.glyph_gap.help",
                    "Room between the app glyphs inside a Space; 0 "
                        + "sets them side by side."
                )
            )
        case .spaceBarFrontAppTitleCap:
            titleCapRow
        case .spaceBarSpringDelay:
            SecondsRow(
                label: L("space_bar.spring_delay", "Spring delay"),
                ms: style.springDelay,
                range: BarSliderBands.springDelaySeconds,
                help: L(
                    "space_bar.spring_delay.help",
                    "Drag a window onto a Space and hold this "
                        + "long for the view to spring to that "
                        + "Space, so you can drop the window into "
                        + "its layout. A quicker drop moves the "
                        + "window there without switching."
                )
            )
        case .spaceBarEnabled, .spaceBarActiveDimFactor,
            .spaceBarStickyBadge, .spaceBarFocusedItemColor:
            let _ = assertionFailure(
                "unrendered Space Bar census key: \(key.rawValue)"
            )
            EmptyView()
        }
    }
}
