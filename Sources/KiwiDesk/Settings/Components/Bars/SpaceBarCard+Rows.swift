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
                        "Shows only while no App Bar does — the App "
                            + "Bar already marks the focused window."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)
            }
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
                    .filter { $0.0 != .gap }
                    .map { ($0.1, $0.0) }
            )
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleActiveIndicator
            )
        case .spaceBarIconSource:
            iconSourceRow
                .searchAnchored(
                    SettingsCatalog.bars.spaceBarStyle.children
                        .spaceBarStyleIconSource
                )
        case .spaceBarGlyphCap:
            glyphCapRow
        case .spaceBarFrontAppTitleCap:
            titleCapRow
                .searchAnchored(
                    SettingsCatalog.bars.spaceBarStyle.children
                        .spaceBarStyleFrontAppTitleCap
                )
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
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleSpringDelay
            )
        case .spaceBarEnabled, .spaceBarDimFactor,
            .spaceBarActiveDimFactor,
            .spaceBarStickyBadge, .spaceBarItemColor,
            .spaceBarActiveItemColor, .spaceBarFocusedItemColor,
            .spaceBarFillColor, .spaceBarHighlightColor,
            .spaceBarHoverFillColor, .spaceBarHoverItemColor,
            .spaceBarGroupBadgeColor, .spaceBarGroupBadgeTextColor:
            let _ = assertionFailure(
                "unrendered Space Bar census key: \(key.rawValue)"
            )
            EmptyView()
        }
    }
}
