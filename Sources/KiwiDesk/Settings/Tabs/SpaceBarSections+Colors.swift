import KiwiDeskCore
import SwiftUI

/// The Space Bar color rows (#293), split from
/// `SpaceBarSections.swift` for the file ceiling. The
/// three-state accent ladder (Text / Active space / Focused
/// window) leads inline — the two-accent system is the bar's
/// defining signature, never hidden behind a disclosure.
extension SpaceBarEditorSection {
    // MARK: - Colors

    /// The three-state ladder is the bar's defining signature —
    /// inline, never behind a disclosure (ui-designer verdict).
    @ViewBuilder var accentLadder: some View {
        AppBarColorGrid {
            HexColorField(
                label: L("space_bar.color.text", "Text"),
                hex: style.textColor
            )
            HexColorField(
                label: L(
                    "space_bar.color.active_text",
                    "Active space"
                ),
                hex: style.activeTextColor
            )
            .help(
                L(
                    "space_bar.color.active_text.help",
                    "Tints the icon of the space currently "
                        + "shown on this display."
                )
            )
            HexColorField(
                label: L(
                    "space_bar.color.focused_item",
                    "Focused window"
                ),
                hex: style.focusedItemColor
            )
            .help(
                L(
                    "space_bar.color.focused_item.help",
                    "Tints the glyph of the focused window, "
                        + "shown only inside the active space."
                )
            )
        }
        Divider()
    }

    @ViewBuilder var otherColors: some View {
        Group {
            HexColorField(
                label: L("space_bar.color.box", "Box"),
                hex: style.boxColor
            )
            HexColorField(
                label: L(
                    "space_bar.color.active_box",
                    "Active box"
                ),
                hex: style.activeBoxColor
            )
            HexColorField(
                label: L(
                    "space_bar.color.highlight",
                    "Highlight"
                ),
                hex: style.highlightColor
            )
            HexColorField(
                label: L("space_bar.color.hover", "Hover"),
                hex: style.hoverColor
            )
            HexColorField(
                label: L(
                    "space_bar.color.hover_text",
                    "Hover text"
                ),
                hex: style.hoverTextColor
            )
        }
        Group {
            HexColorField(
                label: L(
                    "space_bar.color.background",
                    "Background"
                ),
                hex: style.backgroundColor
            )
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
                        + "from the text color. Grouping is "
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
