import KiwiDeskCore
import SwiftUI

/// The 2-column swatch grid the bar color runs share (#2):
/// both colour cards wrap their `HexColorField`s in this so the
/// two read as one grid. Flexible columns, so the grids span
/// the pane's full width identically; a row's own label width
/// sets where the swatch sits inside its (equal-width) cell.
struct AppBarColorGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
            ],
            alignment: .leading,
            spacing: 8
        ) {
            content
        }
    }
}

/// The App Bar colors block (#374): the two the preview
/// reflects most inline, the rest behind "Advanced colors" —
/// the Space Bar's exact tiering (`SpaceBarColorsGroup`). An
/// interim card: the census places bar colours in Advanced
/// Colours, which the Colours phase renders; until then this
/// keeps the only colour GUI alive.
struct AppBarColorsGroup: View {
    @Binding var style: AppBarStyle
    /// Whether the editor is off, and the explanation to show
    /// while it is. Taken as parameters rather than letting the
    /// caller wrap this whole view in a `GreyOut`: the gate has
    /// to reach the disclosure's *content* and skip its label,
    /// because a disabled `DisclosureGroup` refuses to toggle in
    /// either direction (owner-confirmed, #527).
    var gatedOff: Bool = false
    var gateHelp: String = ""
    /// The Gap-indicator grey for the two accent inks, resolved
    /// by the caller (`BarsGateContext.gapOnly`) — false while
    /// `gatedOff`, so the two never compound.
    var gapOnly: Bool = false
    @State private var advancedColorsExpanded = false

    private var gate: GreyOut {
        GreyOut(active: gatedOff, help: gateHelp)
    }

    var body: some View {
        AppBarColorGrid { inlineColors }
            .modifier(gate)
        SettingsDisclosure(
            SettingsCatalog.bars.appBarAdvancedColors,
            chrome: .inline(font: .subheadline),
            isExpanded: $advancedColorsExpanded,
            scrollHoisted: true
        ) {
            AppBarColorGrid { advancedColors }
                .padding(.top, 8)
                .modifier(gate)
        }
    }

    // The two the preview reflects most, kept inline: the fill
    // under the items and the active-item indicator accent.
    @ViewBuilder private var inlineColors: some View {
        HexColorField(
            label: L("app_bar.color.fill", "Fill"),
            hex: $style.fillColor
        )
        HexColorField(
            label: L("app_bar.color.highlight", "Highlight"),
            hex: $style.highlightColor
        )
        .modifier(
            GreyOut(active: gapOnly, help: BarsGateHelp.gapOnly)
        )
    }

    // The remaining palette, behind the disclosure.
    @ViewBuilder private var advancedColors: some View {
        Group {
            HexColorField(
                label: L("app_bar.color.item", "Item"),
                hex: $style.itemColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.active_item",
                    "Active item"
                ),
                hex: $style.activeItemColor
            )
            .modifier(
                GreyOut(
                    active: gapOnly,
                    help: BarsGateHelp.gapOnly
                )
            )
            HexColorField(
                label: L("app_bar.color.hover_fill", "Hover fill"),
                hex: $style.hoverFillColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.hover_item",
                    "Hover item"
                ),
                hex: $style.hoverItemColor
            )
        }
        Group {
            HexColorField(
                label: L(
                    "app_bar.color.group_badge",
                    "Group badge"
                ),
                hex: $style.groupBadgeColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.badge_text",
                    "Badge text"
                ),
                hex: $style.groupBadgeTextColor
            )
        }
    }
}
