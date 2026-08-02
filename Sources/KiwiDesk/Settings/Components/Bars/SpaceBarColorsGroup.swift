import KiwiDeskCore
import SwiftUI

/// The Space Bar colors block (#293/#374): the three-state
/// accent ladder inline (the two-accent system is the bar's
/// defining signature, never behind a disclosure), then the
/// remaining palette shut behind "Advanced colors" — the App
/// Bar's exact tiering. The copy-appearance action moved to the
/// App Bar card's Style drawer (the census's placement — it
/// copies App Bar → Space Bar). An interim card: the census
/// places bar colours in Advanced Colours, which the Colours
/// phase renders; until then this keeps the only colour GUI
/// alive.
struct SpaceBarColorsGroup: View {
    @ObservedObject var model: SettingsModel
    /// Whether the bar is off, and the explanation to show while
    /// it is. Taken as parameters rather than letting the caller
    /// wrap this whole view in a `GreyOut`: the gate has to reach
    /// the disclosure's *content* and skip its label, because a
    /// disabled `DisclosureGroup` refuses to toggle in either
    /// direction (owner-confirmed, #527) — wrapping it from
    /// outside strands the drawer and hides the colors it holds.
    var gatedOff: Bool = false
    var gateHelp: String = ""
    @State private var advancedColorsExpanded = false

    private var style: Binding<SpaceBarStyle> {
        $model.config.settings.spaceBarStyle
    }

    private var gate: GreyOut {
        GreyOut(active: gatedOff, help: gateHelp)
    }

    var body: some View {
        accentLadder
            .modifier(gate)
        SettingsDisclosure(
            SettingsCatalog.bars.spaceBarAdvancedColors,
            chrome: .inline(font: .subheadline),
            isExpanded: $advancedColorsExpanded,
            scrollHoisted: true
        ) {
            AppBarColorGrid { advancedColors }
                .padding(.top, 8)
                .modifier(gate)
        }
    }

    /// The three-state ladder is the bar's defining signature —
    /// inline, never behind a disclosure (ui-designer verdict).
    @ViewBuilder private var accentLadder: some View {
        AppBarColorGrid {
            HexColorField(
                label: L("space_bar.color.item", "Item"),
                hex: style.itemColor
            )
            HexColorField(
                label: L(
                    "space_bar.color.active_space",
                    "Active space"
                ),
                hex: style.activeItemColor
            )
            .help(
                L(
                    "space_bar.color.active_space.help",
                    "Tints the active space's identifier and "
                        + "its app glyphs."
                )
            )
            HexColorField(
                label: L(
                    "space_bar.color.focused_item",
                    "Focused window"
                ),
                hex: style.focusedItemColor
            )
            .modifier(
                GreyOut(
                    // Nothing to tint when in-chip glyphs are
                    // native images AND there's no front-app
                    // name (native images take no tint). The
                    // "name only on horizontal" half mirrors
                    // SpaceBarOverlay+FrontApp's name-visibility
                    // rule — keep in step if that changes.
                    active: style.wrappedValue.iconSource
                        == .appImage
                        && !(style.wrappedValue.showFrontApp
                            && style.wrappedValue.edge
                                .isHorizontal),
                    help: L(
                        "space_bar.color.focused_item.help",
                        "Tints the focused window — its glyph in "
                            + "the active Space and the front-app "
                            + "segment. Glyph tint needs Glyphs "
                            + "icon mode."
                    )
                )
            )
        }
    }

    @ViewBuilder private var advancedColors: some View {
        Group {
            HexColorField(
                label: L("space_bar.color.fill", "Fill"),
                hex: style.fillColor
            )
            HexColorField(
                label: L(
                    "space_bar.color.highlight",
                    "Highlight"
                ),
                hex: style.highlightColor
            )
            HexColorField(
                label: L("space_bar.color.hover_fill", "Hover fill"),
                hex: style.hoverFillColor
            )
            HexColorField(
                label: L(
                    "space_bar.color.hover_item",
                    "Hover item"
                ),
                hex: style.hoverItemColor
            )
        }
        Group {
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
                        + "space; inactive spaces mute them "
                        + "from the item color. Grouping is "
                        + "always on."
                )
            )
            HexColorField(
                label: L(
                    "space_bar.color.badge_text",
                    "Badge text"
                ),
                hex: style.groupBadgeTextColor
            )
        }
    }
}
