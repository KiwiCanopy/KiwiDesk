/// Localized row labels for `BordersKey` (#678).

extension BordersKey {
    var text: SettingRowText {
        switch self {
        case .borderEnabled:
            return .text("border.enabled")
        case .borderFocusedColor:
            return .text("border.title")
        case .borderUnfocusedEnabled:
            return .text("border.unfocused_enabled")
        case .borderUnfocusedColor:
            return .text("border.color.unfocused")
        case .borderWidth:
            return .text("border.width")
        case .borderCorner:
            return .text("border.corner_style")
        case .borderGlow:
            return .text("border.glow")
        case .borderGlowSizeAuto:
            return .text("border.glow_size.auto")
        case .borderGlowSize:
            return .text("border.glow_size")
        case .borderDrawOrder:
            return .none
        case .borderFitGapsExtraSpacing:
            return .text("border.fit_gaps.extra_spacing")
        case .borderFitGaps:
            return .text("border.fit_gaps.action")
        case .stickyMark:
            return .text("sticky.mark", help: "sticky.mark.help")
        case .floatingMark:
            return .text("floating.mark", help: "floating.mark.help")
        case .stickyDesktopReach:
            return .text(
                "sticky.desktop_reach",
                help: "sticky.desktop_reach.help"
            )
        case .stickyColor:
            return .text("sticky.color")
        case .dragGhostEnabled, .dragDropZoneEnabled:
            return .text("drag.enabled")
        case .dragGhostBorder, .dragDropZoneBorder:
            return .text("drag.border")
        case .dragGhostBorderColor:
            return .text("colors.ghost_border")
        case .dragDropZoneBorderColor:
            return .text("colors.drop_zone_border")
        case .dragGhostBorderAlignment,
            .dragDropZoneBorderAlignment:
            return .none
        case .dragGhostFill, .dragDropZoneFill:
            return .text("drag.fill")
        case .dragGhostFillColor:
            return .text("colors.ghost_fill")
        case .dragDropZoneFillColor:
            return .text("colors.drop_zone_fill")
        case .floatingColor:
            return .text("floating.color")
        case .pocketColor:
            return .text("pocket.color")
        }
    }
}
