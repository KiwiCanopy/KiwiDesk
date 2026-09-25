/// The shelf both bars sit on (`KiwiShelf`, #1517) slice of the
/// census. Its card also draws the three Show rows, whose keys
/// stay with the value they write (`spaceBarEnabled`, the two
/// layout App Bar toggles).

enum KiwiShelfKey: String, CaseIterable, Hashable {
    case edge = "settings.kiwishelf.edge"
    case thickness = "settings.kiwishelf.thickness"
    case alignment = "settings.kiwishelf.alignment"
    case order = "settings.kiwishelf.order"
    case minimum = "settings.kiwishelf.minimum"
    case background = "settings.kiwishelf.backgroundStyle"
    case backgroundFit = "settings.kiwishelf.backgroundFit"
    case cornerRoundness = "settings.kiwishelf.cornerRoundness"
    case itemGap = "settings.kiwishelf.itemGap"
    case fontSizeAuto = "settings.kiwishelf.fontSize (auto)"
    case fontSize = "settings.kiwishelf.fontSize"
    case outerMargin = "settings.kiwishelf.outerMargin"
    case innerMargin = "settings.kiwishelf.innerMargin"
    case liquidGlass = "settings.kiwishelf.liquidGlass"
    case iconSource = "settings.kiwishelf.iconSource"
    case dimFactor = "settings.kiwishelf.dimFactor"
    case fillColor = "settings.kiwishelf.fillColor"
    case itemColor = "settings.kiwishelf.itemColor"
    case activeItemColor = "settings.kiwishelf.activeItemColor"
    case highlightColor = "settings.kiwishelf.highlightColor"
    case hoverFillColor = "settings.kiwishelf.hoverFillColor"
    case hoverItemColor = "settings.kiwishelf.hoverItemColor"
    case groupBadgeColor = "settings.kiwishelf.groupBadgeColor"
    case groupBadgeTextColor = "settings.kiwishelf.groupBadgeTextColor"
}

extension KiwiShelfKey {
    /// The three Show switches: every row but those greys while
    /// none is on. Order and minimum further need BOTH bars, which
    /// is their wiring's predicate (`BarsGates.bothBarsShow`).
    static let showGate = SettingGate.anyOf([
        .spaceBar(.spaceBarEnabled),
        .layoutAppBar(.monocleAppBarEnabled),
        .layoutAppBar(.scrollingAppBarEnabled),
    ])

    var placement: SettingPlacement {
        switch self {
        case .edge, .thickness, .alignment, .order, .minimum:
            return .row(.bars, .kiwishelf, .atRest, gate: Self.showGate)
        case .background, .cornerRoundness, .itemGap, .fontSizeAuto,
            .outerMargin, .innerMargin, .iconSource:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: Self.showGate
            )
        case .backgroundFit:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.background))
            )
        case .fontSize:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.fontSizeAuto))
            )
        case .liquidGlass:
            // Written by the one Liquid Glass row (#1307).
            return .luaOnly
        case .dimFactor:
            return .luaOnly
        case .fillColor, .itemColor, .activeItemColor, .highlightColor:
            return .row(
                .advancedColours,
                .kiwishelf,
                .atRest,
                gate: Self.showGate
            )
        case .hoverFillColor, .hoverItemColor, .groupBadgeColor,
            .groupBadgeTextColor:
            return .row(
                .advancedColours,
                .kiwishelf,
                .showMore,
                gate: Self.showGate
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
        case .thickness:
            return .text(
                "kiwishelf.thickness",
                help: "kiwishelf.thickness.help"
            )
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
        case .liquidGlass, .dimFactor:
            return .none
        case .iconSource:
            return .text(
                "kiwishelf.icon_source.label",
                help: "kiwishelf.icon_source.help"
            )
        case .fillColor:
            return .text("kiwishelf.color.fill")
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
