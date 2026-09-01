/// Localized row labels for `BordersKey` (#678).

extension BordersKey {
    var text: SettingRowText {
        switch self {
        case .borderEnabled:
            return .text("border.enabled")
        case .borderFocusedColor:
            return .text("border.color.focused")
        case .borderUnfocusedEnabled:
            return .text("border.unfocused_enabled")
        case .borderUnfocusedColor:
            return .text("border.color.unfocused")
        case .borderWidthMaster:
            return .text("border.width")
        case .borderCornerMaster:
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
        case .dragGhostBorderColor, .dragDropZoneBorderColor:
            return .text("drag.border")
        case .borderWidth, .borderCorner,
            .dragGhostBorderWidth, .dragDropZoneBorderWidth,
            .dragGhostBorderAlignment,
            .dragDropZoneBorderAlignment,
            .dragCornerRadius:
            return .none
        case .dragGhostFill, .dragDropZoneFill:
            return .text("drag.fill")
        case .dragGhostFillColor, .dragDropZoneFillColor:
            return .text("drag.fill")
        case .floatingColor:
            return .text("floating.color")
        }
    }
}
