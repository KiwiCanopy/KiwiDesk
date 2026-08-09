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
        // The Borders card's two rows. Each is a master over
        // several stored leaves, none of which names a row —
        // `settings.borderStyle.width` and `.cornerStyle` fall
        // through to the surfaceless group below with the drag
        // pair's, because the card asks about all of them at
        // once and about none of them individually.
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
        case .borderWidth, .borderCorner,
            .dragGhostBorderWidth, .dragDropZoneBorderWidth,
            .dragGhostBorderAlignment,
            .dragDropZoneBorderAlignment,
            .dragCornerRadius:
            // Surfaceless, so no label — either written by a
            // master row that carries the label, or (the two
            // alignments) untouched by the GUI at all.
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
