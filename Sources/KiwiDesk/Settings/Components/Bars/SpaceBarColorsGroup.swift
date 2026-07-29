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
        copyAppearance
            .modifier(gate)
        accentLadder
            .modifier(gate)
        // LOAD-BEARING, and so is its twin in `AppBarGroups`:
        // both drawers mount the ONE surface-free
        // `advancedColors` declaration, so a reveal lands on
        // whichever bar editor is already open, rather than
        // yanking a Space Bar reader across the switch to an
        // identically-named drawer. Only one editor is ever
        // mounted, so the shared id is never ambiguous — but
        // deleting this mount silently restores the
        // scroll-to-nothing bug for this side
        // (`SettingsCatalogArgumentTests` pins both references).
        SettingsDisclosure(
            SettingsCatalog.bars.advancedColors,
            chrome: .inline(font: .subheadline),
            isExpanded: $advancedColorsExpanded,
            scrollHoisted: true
        ) {
            AppBarColorGrid { advancedColors }
                .padding(.top, 8)
                .modifier(gate)
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
