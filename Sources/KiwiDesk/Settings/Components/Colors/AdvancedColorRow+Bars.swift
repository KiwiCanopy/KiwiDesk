import KiwiDeskCore
import SwiftUI

/// The two bar groups' swatches. Labels and help are the strings
/// the retired interim colour cards authored — same English, so
/// the eleven translations carry over; this file is now their
/// only `scripts/extract-keys`-visible call site.
extension AdvancedColorRow {
    @ViewBuilder func appBarRow(_ key: AppBarKey) -> some View {
        let style = settings.appBarStyle
        switch key {
        case .appBarFillColor:
            HexColorField(
                label: L("app_bar.color.fill", "Fill"),
                hex: style.fillColor
            )
        case .appBarHighlightColor:
            HexColorField(
                label: L("app_bar.color.highlight", "Highlight"),
                hex: style.highlightColor
            )
            .modifier(
                gated(
                    gates.bars.gapOnly,
                    BarsGateHelp.sentence(for: .gapOnly)
                )
            )
        case .appBarItemColor:
            HexColorField(
                label: L("app_bar.color.item", "Item"),
                hex: style.itemColor
            )
        case .appBarActiveItemColor:
            HexColorField(
                label: L("app_bar.color.active_item", "Active item"),
                hex: style.activeItemColor
            )
            .modifier(
                gated(
                    gates.bars.gapOnly,
                    BarsGateHelp.sentence(for: .gapOnly)
                )
            )
        case .appBarHoverFillColor:
            HexColorField(
                label: L("app_bar.color.hover_fill", "Hover fill"),
                hex: style.hoverFillColor
            )
        case .appBarHoverItemColor:
            HexColorField(
                label: L("app_bar.color.hover_item", "Hover item"),
                hex: style.hoverItemColor
            )
        case .appBarGroupBadgeColor:
            HexColorField(
                label: L("app_bar.color.group_badge", "Group badge"),
                hex: style.groupBadgeColor
            )
        case .appBarGroupBadgeTextColor:
            HexColorField(
                label: L("app_bar.color.badge_text", "Badge text"),
                hex: style.groupBadgeTextColor
            )
        default:
            let _ = assertionFailure(
                "non-colour App Bar key in Advanced Colours: "
                    + key.rawValue
            )
            EmptyView()
        }
    }

    @ViewBuilder func spaceBarRow(_ key: SpaceBarKey) -> some View {
        let style = settings.spaceBarStyle
        switch key {
        case .spaceBarItemColor:
            HexColorField(
                label: L("space_bar.color.item", "Item"),
                hex: style.itemColor
            )
        case .spaceBarActiveItemColor:
            HexColorField(
                label: L(
                    "space_bar.color.active_space",
                    "Active Space"
                ),
                hex: style.activeItemColor
            )
            .help(
                L(
                    "space_bar.color.active_space.help",
                    "Tints the active Space's identifier and "
                        + "its app glyphs."
                )
            )
        case .spaceBarFocusedItemColor:
            HexColorField(
                label: L(
                    "space_bar.color.focused_item",
                    "Focused window"
                ),
                hex: style.focusedItemColor
            )
            .modifier(
                gated(gates.focusedItemInert, focusedItemHelp)
            )
        case .spaceBarFillColor:
            HexColorField(
                label: L("space_bar.color.fill", "Fill"),
                hex: style.fillColor
            )
        case .spaceBarHighlightColor:
            HexColorField(
                label: L("space_bar.color.highlight", "Highlight"),
                hex: style.highlightColor
            )
        case .spaceBarHoverFillColor:
            HexColorField(
                label: L("space_bar.color.hover_fill", "Hover fill"),
                hex: style.hoverFillColor
            )
        case .spaceBarHoverItemColor:
            HexColorField(
                label: L("space_bar.color.hover_item", "Hover item"),
                hex: style.hoverItemColor
            )
        case .spaceBarGroupBadgeColor:
            HexColorField(
                label: L(
                    "space_bar.color.group_badge",
                    "Group badge"
                ),
                hex: style.groupBadgeColor
            )
            .help(
                L(
                    "space_bar.color.group_badge.help",
                    "Count and overflow badges on the active "
                        + "Space; inactive Spaces mute them "
                        + "from the item color. Grouping is "
                        + "always on."
                )
            )
        case .spaceBarGroupBadgeTextColor:
            HexColorField(
                label: L("space_bar.color.badge_text", "Badge text"),
                hex: style.groupBadgeTextColor
            )
        default:
            let _ = assertionFailure(
                "non-colour Space Bar key in Advanced Colours: "
                    + key.rawValue
            )
            EmptyView()
        }
    }

    /// The icon mode is INTERPOLATED from the picker entry's own
    /// key rather than named as text (#818) — this help lives on
    /// another page than the picker it names, which is exactly
    /// where a hand-typed label drifts unnoticed.
    private var focusedItemHelp: String {
        L(
            "space_bar.color.focused_item.help",
            "Tints the focused window — its glyph in the active "
                + "Space and the front-app segment. Glyph tint "
                + "needs the \u{201C}%1$@\u{201D} icon mode.",
            L("app_bar.icon_source.app_font", "Glyphs")
        )
    }
}
