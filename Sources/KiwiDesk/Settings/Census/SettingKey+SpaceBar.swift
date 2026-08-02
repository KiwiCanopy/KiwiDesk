/// The Space Bar (`SpaceBarStyle`) slice of the census.

enum SpaceBarKey: String, CaseIterable, Hashable {
    case spaceBarEnabled = "settings.spaceBarStyle.enabled"
    case spaceBarEdge = "settings.spaceBarStyle.edge"
    case spaceBarAlignment = "settings.spaceBarStyle.alignment"
    case spaceBarBackground = "settings.spaceBarStyle.backgroundStyle"
    case spaceBarLiquidGlass = "settings.spaceBarStyle.liquidGlass"
    case spaceBarBackgroundFit = "settings.spaceBarStyle.backgroundFit"
    case spaceBarActiveIndicator = "settings.spaceBarStyle.activeIndicator"
    case spaceBarIconSource = "settings.spaceBarStyle.iconSource"
    case spaceBarHideEmpty = "settings.spaceBarStyle.hideEmpty"
    case spaceBarShowFrontApp = "settings.spaceBarStyle.showFrontApp"
    case spaceBarSpringDelay = "settings.spaceBarStyle.springDelay"
    case spaceBarThickness = "settings.spaceBarStyle.thickness"
    case spaceBarItemSizeAuto = "settings.spaceBarStyle.itemSize (auto)"
    case spaceBarItemSize = "settings.spaceBarStyle.itemSize"
    case spaceBarItemGap = "settings.spaceBarStyle.itemGap"
    case spaceBarFontSizeAuto = "settings.spaceBarStyle.fontSize (auto)"
    case spaceBarFontSize = "settings.spaceBarStyle.fontSize"
    case spaceBarGlyphCap = "settings.spaceBarStyle.glyphCap"
    case spaceBarCornerRoundness = "settings.spaceBarStyle.cornerRoundness"
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
    case copyAppearance = "(action) spaceBarStyle.copyAppearance"
}

extension SpaceBarKey {
    var placement: SettingPlacement {
        switch self {
        case .spaceBarEnabled, .spaceBarEdge, .spaceBarHideEmpty,
            .spaceBarShowFrontApp, .spaceBarThickness:
            return .row(.bars, .spaceBar, .atRest)
        case .spaceBarAlignment, .spaceBarBackground, .spaceBarActiveIndicator,
            .spaceBarIconSource, .spaceBarSpringDelay, .spaceBarItemSizeAuto,
            .spaceBarItemGap, .spaceBarFontSizeAuto, .spaceBarGlyphCap,
            .spaceBarCornerRoundness:
            return .row(.bars, .spaceBar, .showMore)
        case .spaceBarItemSize:
            return .row(
                .bars,
                .spaceBar,
                .showMore,
                gate: .setting(.spaceBar(.spaceBarItemSizeAuto))
            )
        case .spaceBarFontSize:
            return .row(
                .bars,
                .spaceBar,
                .showMore,
                gate: .setting(.spaceBar(.spaceBarFontSizeAuto))
            )
        case .spaceBarLiquidGlass:
            // platform-gated
            return .row(.bars, .spaceBar, .showMore)
        case .spaceBarBackgroundFit:
            // Boxed draws no shared plate to size.
            return .row(
                .bars,
                .spaceBar,
                .showMore,
                gate: .setting(.spaceBar(.spaceBarBackground))
            )
        case .spaceBarDimFactor, .spaceBarActiveDimFactor,
            .spaceBarStickyBadge:
            return .luaOnly
        case .spaceBarItemColor, .spaceBarActiveItemColor, .spaceBarFillColor,
            .spaceBarHighlightColor, .spaceBarHoverFillColor,
            .spaceBarHoverItemColor, .spaceBarGroupBadgeColor,
            .spaceBarGroupBadgeTextColor:
            return .row(.advancedColours, .spaceBar, .atRest)
        case .spaceBarFocusedItemColor:
            // Nothing to tint when glyphs are native images and
            // no front-app name renders (icon source + front
            // app + edge, SpaceBarColorsGroup).
            return .row(
                .advancedColours,
                .spaceBar,
                .atRest,
                gate: .anyOf([
                    .spaceBar(.spaceBarIconSource),
                    .spaceBar(.spaceBarShowFrontApp),
                    .spaceBar(.spaceBarEdge),
                ])
            )
        case .copyAppearance:
            // Table moves it into the App Bar card (it copies
            // App Bar → Space Bar); it needs the Space Bar on,
            // not the App Bar shown.
            return .row(
                .bars,
                .appBar,
                .showMore,
                gate: .setting(.spaceBar(.spaceBarEnabled)),
                exemptFromContainerGate: true
            )
        }
    }
}

extension SpaceBarKey {
    var text: SettingRowText {
        switch self {
        case .spaceBarEnabled:
            return .text("space_bar.enabled", help: "space_bar.enabled.help")
        case .spaceBarEdge:
            return .text(
                "space_bar.edge.label",
                help: "space_bar.edge.label.help"
            )
        case .spaceBarAlignment:
            return .text(
                "space_bar.alignment.label",
                help: "space_bar.alignment.label.help"
            )
        case .spaceBarBackground:
            return .text("space_bar.background_style.label")
        case .spaceBarLiquidGlass:
            return .text(
                "app_bar.liquid_glass",
                help: "app_bar.liquid_glass.help"
            )
        case .spaceBarBackgroundFit:
            return .text("space_bar.background_fit.label")
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
        case .spaceBarThickness:
            return .text("space_bar.thickness")
        case .spaceBarItemSizeAuto:
            return .text("space_bar.item_size.auto")
        case .spaceBarItemSize:
            return .text("space_bar.item_size")
        case .spaceBarItemGap:
            return .text("space_bar.item_gap")
        case .spaceBarFontSizeAuto:
            return .text("space_bar.font_size.auto")
        case .spaceBarFontSize:
            return .text("space_bar.font_size")
        case .spaceBarGlyphCap:
            return .text(
                "space_bar.glyph_cap",
                help: "space_bar.glyph_cap.help"
            )
        case .spaceBarCornerRoundness:
            return .text("space_bar.corner_roundness")
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
        case .copyAppearance:
            return .text(
                "space_bar.copy_appearance",
                caption: "space_bar.copy_appearance.caption",
                help: "space_bar.copy_appearance.help"
            )
        }
    }
}
