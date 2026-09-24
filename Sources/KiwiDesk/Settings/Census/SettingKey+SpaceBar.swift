/// The Space Bar (`SpaceBarStyle`) slice of the census.

enum SpaceBarKey: String, CaseIterable, Hashable {
    case spaceBarEnabled = "settings.spaceBarStyle.enabled"
    case spaceBarActiveIndicator = "settings.spaceBarStyle.activeIndicator"
    case spaceBarHideEmpty = "settings.spaceBarStyle.hideEmpty"
    case spaceBarShowFrontApp = "settings.spaceBarStyle.showFrontApp"
    case spaceBarSpringDelay = "settings.spaceBarStyle.springDelay"
    case spaceBarGlyphCap = "settings.spaceBarStyle.glyphCap"
    case spaceBarFrontAppTitleCap =
        "settings.spaceBarStyle.frontAppTitleCap"
    case spaceBarActiveDimFactor = "settings.spaceBarStyle.activeDimFactor"
    case spaceBarStickyBadge = "settings.spaceBarStyle.stickyBadge"
    case spaceBarFocusedItemColor = "settings.spaceBarStyle.focusedItemColor"
}

extension SpaceBarKey {
    var placement: SettingPlacement {
        switch self {
        case .spaceBarEnabled:
            // Owns the .spaceBar container gate, and is drawn in
            // the KiwiShelf card's Show group, which has none.
            return .row(.bars, .kiwishelf, .atRest)
        case .spaceBarHideEmpty, .spaceBarShowFrontApp,
            .spaceBarActiveIndicator, .spaceBarSpringDelay,
            .spaceBarGlyphCap:
            return .row(.bars, .spaceBar, .atRest)
        case .spaceBarFrontAppTitleCap:
            // Inert while front segment is off.
            return .row(
                .bars,
                .spaceBar,
                .atRest,
                gate: .setting(.spaceBar(.spaceBarShowFrontApp))
            )
        case .spaceBarActiveDimFactor, .spaceBarStickyBadge:
            return .luaOnly
        case .spaceBarFocusedItemColor:
            // Inert when front-app is off or icon source does not tint.
            return .row(
                .advancedColours,
                .kiwishelf,
                .showMore,
                gate: .anyOf([
                    .spaceBar(.spaceBarEnabled),
                    .kiwishelf(.iconSource),
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
        case .spaceBarActiveDimFactor, .spaceBarStickyBadge:
            return .none
        case .spaceBarFocusedItemColor:
            return .text(
                "space_bar.color.focused_item",
                help: "space_bar.color.focused_item.help"
            )
        }
    }
}
