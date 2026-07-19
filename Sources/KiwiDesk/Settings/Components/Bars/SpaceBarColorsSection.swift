import KiwiDeskCore
import SwiftUI

/// The Space Bar colors block (#293/#374): copy button, the
/// three-state accent ladder inline (the two-accent system is
/// the bar's defining signature, never behind a disclosure),
/// then the remaining palette shut behind "Advanced colors" —
/// the App Bar's exact tiering. A standalone struct, not an
/// extension: the disclosure owns `@State`, which extensions
/// cannot hold. Expansion resets when the editor is torn down
/// (tab switch) — the app-wide disclosure precedent.
struct SpaceBarColorsSection: View {
    @ObservedObject var model: SettingsModel
    @State private var advancedColorsExpanded = false

    private var style: Binding<SpaceBarStyle> {
        $model.config.settings.spaceBarStyle
    }

    var body: some View {
        copyAppearance
        accentLadder
        DisclosureGroup(isExpanded: $advancedColorsExpanded) {
            AppBarColorGrid { advancedColors }
                .padding(.top, 8)
        } label: {
            Text(
                L("bars.advanced_colors", "Advanced colors")
            )
            .font(.subheadline)
        }
    }

    /// One-shot copy, then fully independent — never a live
    /// inherit. Excludes enabled and edge (visibility and
    /// placement are not appearance). Leads the colors section
    /// (colors are its most consequential effect), leading-
    /// aligned in the Reset-Overrides button language; the
    /// one-shot caveat rides a persistent caption, never
    /// hover alone.
    private var copyAppearance: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                model.config.settings.spaceBarStyle
                    .copyAppearance(
                        from: model.config.settings.appBarStyle
                    )
            } label: {
                Text(
                    L(
                        "space_bar.copy_appearance",
                        "Copy App Bar appearance…"
                    )
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(
                L(
                    "space_bar.copy_appearance.help",
                    "Takes the App Bar's current sizes, style, "
                        + "and colors once; edits afterwards "
                        + "stay independent."
                )
            )
            Text(
                L(
                    "space_bar.copy_appearance.caption",
                    "Copies the App Bar's current sizes, "
                        + "style, and colors — a one-time "
                        + "starting point, not a live link."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// The three-state ladder is the bar's defining signature —
    /// inline, never behind a disclosure (ui-designer verdict).
    @ViewBuilder private var accentLadder: some View {
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
    }

    @ViewBuilder private var advancedColors: some View {
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
            // Under Liquid Glass this field IS the glass tint
            // (QA 2026-07-19) — relabel so that's discoverable.
            // Plain fills the strip from Box, so it's the one
            // mode where this color never shows: grey (#171).
            HexColorField(
                label: style.wrappedValue.tabBackground
                    == .material
                    ? L("space_bar.color.tint", "Tint")
                    : L(
                        "space_bar.color.background",
                        "Background"
                    ),
                hex: style.backgroundColor
            )
            .modifier(
                GreyOut(
                    active: style.wrappedValue.tabBackground
                        == .plain,
                    help: L(
                        "space_bar.color.background.plain",
                        "Plain fills the whole strip with the "
                            + "Box color, so the background "
                            + "color is never visible."
                    )
                )
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
