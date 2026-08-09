/// The row LABELS for `BordersKey`, split from the placement
/// switch so neither file crosses the size ceiling (the
/// `SettingKey+LayoutText` shape).

extension BordersKey {
    var text: SettingRowText {
        switch self {
        case .borderEnabled:
            return .text("border.enabled")
        // On the Focus-border card each ring tint could be
        // "Color", the card being the context. In a Borders
        // group holding three tints, two rows named "Color" name
        // nothing, so both took the wording their VoiceOver
        // labels already carried (#678 Phase 3).
        case .borderFocusedColor:
            return .text("border.color.focused")
        case .borderUnfocusedEnabled:
            return .text("border.unfocused_enabled")
        case .borderUnfocusedColor:
            return .text("border.color.unfocused")
        case .borderWidth:
            return .text("border.width")
        // The Square/Rounded picker in the Borders card. It is
        // what actually renders for BOTH corner settings, so
        // `dragCornerRadius` names no row of its own below.
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
        case .stickyColor:
            return .text("sticky.color")
        case .dragGhostEnabled, .dragDropZoneEnabled:
            return .text("drag.enabled")
        case .dragGhostBorder, .dragDropZoneBorder:
            return .text("drag.border")
        // The drag tints go the other way: they reuse their
        // toggles' labels, because the Border/Fill sub-grouping
        // that made a bare "Color" readable is not on the colour
        // page either.
        case .dragGhostBorderColor, .dragDropZoneBorderColor:
            return .text("drag.border")
        case .dragGhostBorderWidth, .dragDropZoneBorderWidth,
            .dragGhostBorderAlignment,
            .dragDropZoneBorderAlignment,
            .dragCornerRadius:
            // GUI_REMOVED_2026-08 — surfaceless, so no label.
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
