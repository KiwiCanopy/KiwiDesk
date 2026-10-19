/// The shelf both bars sit on (`KiwiShelf`, #1517) slice of the
/// census. Its card also draws the three Show rows, whose keys
/// stay with the value they write (`spaceBarVisibility`, the two
/// layout App Bar visibilities).

enum KiwiShelfKey: String, CaseIterable, Hashable {
    /// The Position master: both bars' edges (#1731), which it
    /// writes through `masterWrites`.
    case edge = "settings.spaceBarStyle.edge (master)"
    case spaceBarEdge = "settings.spaceBarStyle.edge"
    case appBarEdge = "settings.appBarStyle.edge"
    /// Each bar's per-screen edges (#1948): a row per screen in
    /// that bar's Per screen drawer.
    case spaceBarScreenEdge = "settings.spaceBarStyle.edgeOverride[screen]"
    case appBarScreenEdge = "settings.appBarStyle.edgeOverride[screen]"
    case thickness = "settings.kiwishelf.thickness"
    case alignment = "settings.kiwishelf.alignment"
    case order = "settings.kiwishelf.order"
    case minimum = "settings.kiwishelf.minimum"
    case background = "settings.kiwishelf.backgroundStyle"
    case backgroundFit = "settings.kiwishelf.backgroundFit"
    case cornerRoundness = "settings.kiwishelf.cornerRoundness"
    case border = "settings.kiwishelf.border"
    case borderWidth = "settings.kiwishelf.borderWidth"
    case highlightWidth = "settings.kiwishelf.highlightWidth"
    case itemGap = "settings.kiwishelf.itemGap"
    case glyphSizeAuto = "settings.kiwishelf.glyphSize (auto)"
    case glyphSize = "settings.kiwishelf.glyphSize"
    case fontSizeAuto = "settings.kiwishelf.fontSize (auto)"
    case fontSize = "settings.kiwishelf.fontSize"
    case fontFamily = "settings.kiwishelf.fontFamily"
    case fontWeight = "settings.kiwishelf.fontWeight"
    case outerMargin = "settings.kiwishelf.outerMargin"
    case innerMargin = "settings.kiwishelf.innerMargin"
    case liquidGlass = "settings.kiwishelf.liquidGlass"
    case iconSource = "settings.kiwishelf.iconSource"
    case dimFactor = "settings.kiwishelf.dimFactor"
    case revealDuration = "settings.kiwishelf.revealDuration"
    case fillColor = "settings.kiwishelf.fillColor"
    case borderColor = "settings.kiwishelf.borderColor"
    case itemColor = "settings.kiwishelf.itemColor"
    case activeItemColor = "settings.kiwishelf.activeItemColor"
    case highlightColor = "settings.kiwishelf.highlightColor"
    case hoverFillColor = "settings.kiwishelf.hoverFillColor"
    case hoverItemColor = "settings.kiwishelf.hoverItemColor"
    case groupBadgeColor = "settings.kiwishelf.groupBadgeColor"
    case groupBadgeTextColor = "settings.kiwishelf.groupBadgeTextColor"
}

extension KiwiShelfKey {
    var placement: SettingPlacement {
        switch self {
        case .edge:
            // A master acknowledges divergence through its `?`
            // and carries no gate (`GapsBordersGates.acknowledged`).
            return .row(.bars, .kiwishelf, .atRest)
        case .thickness, .alignment, .order, .minimum:
            return .row(.bars, .kiwishelf, .atRest)
        case .spaceBarEdge, .appBarEdge, .spaceBarScreenEdge,
            .appBarScreenEdge:
            return .row(.bars, .kiwishelf, .showMore)
        case .background, .cornerRoundness, .border, .highlightWidth,
            .itemGap, .glyphSizeAuto, .fontSizeAuto, .fontFamily,
            .outerMargin, .innerMargin, .iconSource:
            return .row(.bars, .kiwishelf, .showMore)
        case .backgroundFit:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.background))
            )
        case .fontWeight:
            // Greyed while the family is not installed.
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.fontFamily))
            )
        case .fontSize:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.fontSizeAuto))
            )
        case .glyphSize:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.glyphSizeAuto))
            )
        case .borderWidth:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.border))
            )
        case .liquidGlass:
            // Written by the one Liquid Glass row (#1307).
            return .luaOnly
        case .dimFactor:
            return .luaOnly
        case .revealDuration:
            // Lua/CLI until its Settings row lands (#761).
            return .luaOnly
        case .activeItemColor, .highlightColor, .hoverFillColor:
            // The accent's bar half (#1857).
            return .row(.advancedColours, .accent, .atRest)
        case .fillColor, .itemColor, .hoverItemColor,
            .groupBadgeColor, .groupBadgeTextColor:
            return .row(.advancedColours, .kiwishelf, .atRest)
        case .borderColor:
            // Inert while the border is off (#1679).
            return .row(
                .advancedColours,
                .kiwishelf,
                .atRest,
                gate: .setting(.kiwishelf(.border))
            )
        }
    }

    var text: SettingRowText {
        switch self {
        case .edge:
            return .text(
                "kiwishelf.edge.label",
                help: "kiwishelf.edge.label.help"
            )
        case .spaceBarEdge:
            return .text("kiwishelf.edge.space_bar")
        case .appBarEdge:
            return .text("kiwishelf.edge.app_bar")
        case .spaceBarScreenEdge:
            return .text("kiwishelf.edge.per_screen.space_bar")
        case .appBarScreenEdge:
            return .text("kiwishelf.edge.per_screen.app_bar")
        case .thickness:
            return .text(
                "kiwishelf.thickness",
                help: "kiwishelf.thickness.help"
            )
        case .glyphSizeAuto:
            return .text(
                "kiwishelf.glyph_size.auto",
                help: "kiwishelf.glyph_size.help"
            )
        case .glyphSize:
            return .text("kiwishelf.glyph_size")
        case .alignment:
            return .text(
                "kiwishelf.alignment.label",
                help: "kiwishelf.alignment.label.help"
            )
        case .order:
            return .text(
                "kiwishelf.order.label",
                help: "kiwishelf.order.label.help"
            )
        case .minimum:
            return .text(
                "kiwishelf.minimum",
                help: "kiwishelf.minimum.help"
            )
        case .background:
            return .text(
                "kiwishelf.background_style.label",
                help: "kiwishelf.background_style.label.help"
            )
        case .backgroundFit:
            return .text(
                "kiwishelf.background_fit.label",
                help: "kiwishelf.background_fit.label.help"
            )
        case .cornerRoundness:
            return .text(
                "kiwishelf.corner_roundness",
                help: "kiwishelf.corner_roundness.help"
            )
        case .border:
            return .text(
                "kiwishelf.border",
                help: "kiwishelf.border.help"
            )
        case .borderWidth:
            return .text("kiwishelf.border_width")
        case .highlightWidth:
            return .text(
                "kiwishelf.highlight_width",
                help: "kiwishelf.highlight_width.help"
            )
        case .itemGap:
            return .text(
                "kiwishelf.item_gap",
                help: "kiwishelf.item_gap.help"
            )
        case .fontSizeAuto:
            return .text(
                "kiwishelf.font_size.auto",
                help: "kiwishelf.font_size.help"
            )
        case .fontSize:
            return .text("kiwishelf.font_size")
        case .fontFamily:
            return .text(
                "kiwishelf.font_family",
                help: "kiwishelf.font_family.help"
            )
        case .fontWeight:
            return .text(
                "kiwishelf.font_weight",
                help: "kiwishelf.font_weight.help"
            )
        case .outerMargin:
            return .text(
                "kiwishelf.outer_margin",
                help: "kiwishelf.outer_margin.help"
            )
        case .innerMargin:
            return .text(
                "kiwishelf.inner_margin",
                help: "kiwishelf.inner_margin.help"
            )
        case .liquidGlass, .dimFactor, .revealDuration:
            return .none
        case .iconSource:
            return .text(
                "kiwishelf.icon_source.label",
                help: "kiwishelf.icon_source.help"
            )
        case .fillColor:
            return .text("kiwishelf.color.fill")
        case .borderColor:
            return .text("kiwishelf.color.border")
        case .itemColor:
            return .text(
                "kiwishelf.color.item",
                help: "kiwishelf.color.item.help"
            )
        case .activeItemColor:
            return .text("kiwishelf.color.active_item")
        case .highlightColor:
            return .text("kiwishelf.color.highlight")
        case .hoverFillColor:
            return .text("kiwishelf.color.hover_fill")
        case .hoverItemColor:
            return .text("kiwishelf.color.hover_item")
        case .groupBadgeColor:
            return .text("kiwishelf.color.group_badge")
        case .groupBadgeTextColor:
            return .text("kiwishelf.color.badge_text")
        }
    }
}
