import KiwiDeskCore

/// The KiwiShelf census rows' label and help keys, split from
/// `SettingKey+KiwiShelf.swift` at the §2.1 ceiling.
extension KiwiShelfKey {
    var text: SettingRowText {
        switch self {
        case .visibility:
            return .text(
                "kiwishelf.show.label",
                help: "kiwishelf.show.visibility.help"
            )
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
        case .liquidGlass, .dimFactor, .revealTimeout, .readingContrast:
            return .none
        case .fillFade:
            return .text(
                "kiwishelf.fill_fade",
                help: "kiwishelf.fill_fade.help"
            )
        case .tintHubAndPlates:
            // Its label names KiwiHub through `kiwihub.name`
            // (`SettingKey.labelNamesKiwiHub`).
            return .text(
                "kiwishelf.tint_hub_and_plates",
                help: "kiwishelf.tint_hub_and_plates.help"
            )
        case .iconSource:
            return .text(
                "kiwishelf.icon_source.label",
                help: "kiwishelf.icon_source.help"
            )
        case .pocketEdge:
            return .text("kiwishelf.edge.pocket")
        case .pocketVisibility:
            return .text("kiwishelf.show.pocket")
        case .pocketScreenEdge:
            return .text("kiwishelf.edge.per_screen.pocket")
        case .maximizedVisibility:
            return .text(
                "layout_defaults.maximize.show_bars",
                help: "layout_defaults.maximize.show_bars.help"
            )
        case .pocketPosition:
            return .text(
                "kiwishelf.pocket_position",
                help: "kiwishelf.pocket_position.help"
            )
        case .revealStyle:
            return .text(
                "kiwishelf.reveal_style.label",
                help: "kiwishelf.reveal_style.label.help"
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
        case .handleColor:
            return .text(
                "kiwishelf.color.handle",
                help: "kiwishelf.color.handle.help"
            )
        }
    }
}
