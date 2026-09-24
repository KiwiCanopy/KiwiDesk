/// The shelf both bars sit on (`KiwiShelf`, #1517) slice of the
/// census. Its card also draws the three Show rows, whose keys
/// stay with the value they write (`spaceBarEnabled`, the two
/// layout App Bar toggles).

enum KiwiShelfKey: String, CaseIterable, Hashable {
    case edge = "settings.kiwishelf.edge"
    case thickness = "settings.kiwishelf.thickness"
    case alignment = "settings.kiwishelf.alignment"
    case order = "settings.kiwishelf.order"
    case share = "settings.kiwishelf.share"
    case background = "settings.kiwishelf.backgroundStyle"
    case backgroundFit = "settings.kiwishelf.backgroundFit"
    case cornerRoundness = "settings.kiwishelf.cornerRoundness"
    case itemGap = "settings.kiwishelf.itemGap"
    case fontSizeAuto = "settings.kiwishelf.fontSize (auto)"
    case fontSize = "settings.kiwishelf.fontSize"
    case outerMargin = "settings.kiwishelf.outerMargin"
    case innerMargin = "settings.kiwishelf.innerMargin"
    case liquidGlass = "settings.kiwishelf.liquidGlass"
}

extension KiwiShelfKey {
    /// Order and share matter only while both bars show.
    static let bothBarsGate = SettingGate.anyOf([
        .spaceBar(.spaceBarEnabled),
        .layoutAppBar(.monocleAppBarEnabled),
        .layoutAppBar(.scrollingAppBarEnabled),
    ])

    var placement: SettingPlacement {
        switch self {
        case .edge, .thickness, .alignment:
            return .row(.bars, .kiwishelf, .atRest)
        case .background, .cornerRoundness, .itemGap, .fontSizeAuto,
            .outerMargin, .innerMargin:
            return .row(.bars, .kiwishelf, .showMore)
        case .order, .share:
            return .row(
                .bars,
                .kiwishelf,
                .atRest,
                gate: Self.bothBarsGate
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
        case .share:
            return .text(
                "kiwishelf.share",
                help: "kiwishelf.share.help"
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
        case .liquidGlass:
            return .none
        }
    }
}
