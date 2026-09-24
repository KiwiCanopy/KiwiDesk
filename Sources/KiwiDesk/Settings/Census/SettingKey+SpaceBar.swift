/// The Space Bar (`SpaceBarStyle`) slice of the census.

enum SpaceBarKey: String, CaseIterable, Hashable {
    case spaceBarEnabled = "settings.spaceBarStyle.enabled"
    case spaceBarActiveIndicator = "settings.spaceBarStyle.activeIndicator"
    case spaceBarIconSource = "settings.spaceBarStyle.iconSource"
    case spaceBarHideEmpty = "settings.spaceBarStyle.hideEmpty"
    case spaceBarShowFrontApp = "settings.spaceBarStyle.showFrontApp"
    case spaceBarSpringDelay = "settings.spaceBarStyle.springDelay"
    case spaceBarGlyphCap = "settings.spaceBarStyle.glyphCap"
    case spaceBarFrontAppTitleCap =
        "settings.spaceBarStyle.frontAppTitleCap"
    case spaceBarDimFactor = "settings.spaceBarStyle.dimFactor"
    case spaceBarActiveDimFactor = "settings.spaceBarStyle.activeDimFactor"
    case spaceBarStickyBadge = "settings.spaceBarStyle.stickyBadge"
    case spaceBarItemColor = "settings.spaceBarStyle.itemColor"
    case spaceBarActiveItemColor = "settings.spaceBarStyle.activeItemColor"
    case spaceBarFocusedItemColor = "settings.spaceBarStyle.focusedItemColor"
    case spaceBarFillColor = "settings.spaceBarStyle.fillColor"
    case spaceBarHighlightColor = "settings.spaceBarStyle.highlightColor"
    case spaceBarHoverFillColor = "settings.spaceBarStyle.hoverFillColor"
    case spaceBarHoverItemColor = "settings.spaceBarStyle.hoverItemColor"
    case spaceBarGroupBadgeColor = "settings.spaceBarStyle.groupBadgeColor"
    case spaceBarGroupBadgeTextColor =
        "settings.spaceBarStyle.groupBadgeTextColor"
}

extension SpaceBarKey {
    var placement: SettingPlacement {
        switch self {
        case .spaceBarEnabled:
            // Owns the .spaceBar container gate, and is drawn in
            // the KiwiShelf card's Show group, which has none.
            return .row(.bars, .kiwishelf, .atRest)
        case .spaceBarHideEmpty, .spaceBarShowFrontApp:
            return .row(.bars, .spaceBar, .atRest)
        case .spaceBarActiveIndicator, .spaceBarIconSource,
            .spaceBarSpringDelay, .spaceBarGlyphCap:
            return .row(.bars, .spaceBar, .showMore)
        case .spaceBarFrontAppTitleCap:
            // Inert while front segment is off.
            return .row(
                .bars,
                .spaceBar,
                .showMore,
                gate: .setting(.spaceBar(.spaceBarShowFrontApp))
            )
        case .spaceBarDimFactor, .spaceBarActiveDimFactor,
            .spaceBarStickyBadge:
            return .luaOnly
        case .spaceBarItemColor, .spaceBarActiveItemColor:
            return .row(.advancedColours, .spaceBar, .atRest)
        case .spaceBarFillColor, .spaceBarHighlightColor,
            .spaceBarHoverFillColor, .spaceBarHoverItemColor,
            .spaceBarGroupBadgeColor, .spaceBarGroupBadgeTextColor:
            return .row(.advancedColours, .spaceBar, .showMore)
        case .spaceBarFocusedItemColor:
            // Inert when front-app is off or icon source does not tint.
            return .row(
                .advancedColours,
                .spaceBar,
                .atRest,
                gate: .anyOf([
                    .spaceBar(.spaceBarIconSource),
                    .spaceBar(.spaceBarShowFrontApp),
                    .kiwishelf(.edge),
                ])
            )
        }
    }
}

extension SpaceBarKey {
    var text: SettingRowText {
        switch self {
        case .spaceBarEnabled:
            return .text("kiwishelf.show.space_bar")
        case .spaceBarActiveIndicator:
            return .text("space_bar.active_indicator.label")
        case .spaceBarIconSource:
            return .text(
                "space_bar.icon_source.label",
                help: "space_bar.icon_source.help"
            )
        case .spaceBarHideEmpty:
            return .text(
                "space_bar.hide_empty",
                help: "space_bar.hide_empty.help"
            )
        case .spaceBarShowFrontApp:
            return .text(
                "space_bar.show_front_app",
                help: "space_bar.show_front_app.help"
            )
        case .spaceBarSpringDelay:
            return .text(
                "space_bar.spring_delay",
                help: "space_bar.spring_delay.help"
            )
        case .spaceBarGlyphCap:
            return .text(
                "space_bar.glyph_cap",
                help: "space_bar.glyph_cap.help"
            )
        case .spaceBarFrontAppTitleCap:
            return .text(
                "space_bar.front_app_title_cap",
                help: "space_bar.front_app_title_cap.help"
            )
        case .spaceBarDimFactor, .spaceBarActiveDimFactor,
            .spaceBarStickyBadge:
            return .none
        case .spaceBarItemColor:
            return .text("space_bar.color.item")
        case .spaceBarActiveItemColor:
            return .text(
                "space_bar.color.active_space",
                help: "space_bar.color.active_space.help"
            )
        case .spaceBarFocusedItemColor:
            return .text(
                "space_bar.color.focused_item",
                help: "space_bar.color.focused_item.help"
            )
        case .spaceBarFillColor:
            return .text("space_bar.color.fill")
        case .spaceBarHighlightColor:
            return .text("space_bar.color.highlight")
        case .spaceBarHoverFillColor:
            return .text("space_bar.color.hover_fill")
        case .spaceBarHoverItemColor:
            return .text("space_bar.color.hover_item")
        case .spaceBarGroupBadgeColor:
            return .text(
                "space_bar.color.group_badge",
                help: "space_bar.color.group_badge.help"
            )
        case .spaceBarGroupBadgeTextColor:
            return .text("space_bar.color.badge_text")
        }
    }
}
