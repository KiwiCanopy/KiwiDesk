/// Borders, sticky/floating marks and drag visuals
/// (`BorderStyle`, `StickyStyle`, `FloatingStyle`,
/// `DragGhost`, `DragDropZone`).

enum BordersKey: String, CaseIterable, Hashable {
    case borderEnabled = "settings.borderStyle.enabled"
    case borderFocusedColor = "settings.borderStyle.focusedColor"
    case borderUnfocusedEnabled = "settings.borderStyle.unfocusedEnabled"
    case borderUnfocusedColor = "settings.borderStyle.unfocusedColor"
    case borderWidth = "settings.borderStyle.width"
    case borderCorner = "settings.borderStyle.cornerStyle"
    case borderGlow = "settings.borderStyle.glow"
    case borderGlowSizeAuto = "settings.borderStyle.glowSize (auto)"
    case borderGlowSize = "settings.borderStyle.glowSize"
    case borderDrawOrder = "settings.borderStyle.drawOrder"
    case borderFitGapsExtraSpacing = "(action) border.fit_gaps.extra_spacing"
    case borderFitGaps = "(action) border.fit_gaps"
    case stickyMark = "settings.stickyStyle.mark"
    case stickyColor = "settings.stickyStyle.color"
    case dragCornerRadius = "settings.dragCornerRadius"
    case dragGhostEnabled = "settings.dragGhost.enabled"
    case dragGhostBorder = "settings.dragGhost.border"
    case dragGhostBorderColor = "settings.dragGhost.borderColor"
    case dragGhostBorderWidth = "settings.dragGhost.borderWidth"
    case dragGhostBorderAlignment = "settings.dragGhost.borderAlignment"
    case dragGhostFill = "settings.dragGhost.fill"
    case dragGhostFillColor = "settings.dragGhost.fillColor"
    case dragDropZoneEnabled = "settings.dragDropZone.enabled"
    case dragDropZoneBorder = "settings.dragDropZone.border"
    case dragDropZoneBorderColor = "settings.dragDropZone.borderColor"
    case dragDropZoneBorderWidth = "settings.dragDropZone.borderWidth"
    case dragDropZoneBorderAlignment = "settings.dragDropZone.borderAlignment"
    case dragDropZoneFill = "settings.dragDropZone.fill"
    case dragDropZoneFillColor = "settings.dragDropZone.fillColor"
    case floatingColor = "settings.floatingStyle.color"
}

extension BordersKey {
    var placement: SettingPlacement {
        switch self {
        case .borderEnabled:
            // Owns the .focusBorder container gate — stays
            // live while the container greys.
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .atRest,
                exemptFromContainerGate: true
            )
        case .borderWidth, .borderFitGapsExtraSpacing:
            return .row(.gapsAndBorders, .focusBorder, .atRest)
        // The .borders container carries no block gate
        // (stickyColor shares it, deliberately ungated), so
        // the border colors ride borderEnabled on the row.
        case .borderFocusedColor:
            return .row(
                .advancedColours,
                .borders,
                .atRest,
                gate: .setting(.borders(.borderEnabled))
            )
        case .borderUnfocusedEnabled, .borderCorner, .borderGlow,
            .borderGlowSizeAuto:
            return .row(.gapsAndBorders, .focusBorder, .showMore)
        case .borderUnfocusedColor:
            return .row(
                .advancedColours,
                .borders,
                .atRest,
                gate: .anyOf([
                    .borders(.borderEnabled),
                    .borders(.borderUnfocusedEnabled),
                ])
            )
        case .stickyColor:
            // The table marks this GATED; the Colours phase
            // ruled it UNGATED and it ships that way. The tint
            // has a consumer the Space Bar does not own — the
            // on-window mark — so no state of the BAR can make
            // it inert, which is why the .borders container
            // carries no block gate at all. (Not "it always
            // tints something": the mark's own toggle can be
            // off, a state the sticky-mark ruling deliberately
            // leaves reachable.)
            return .row(.advancedColours, .borders, .atRest)
        case .borderGlowSize:
            // Glow on, and not auto-sized (AutoGatedGroup).
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .showMore,
                gate: .anyOf([
                    .borders(.borderGlow),
                    .borders(.borderGlowSizeAuto),
                ])
            )
        case .borderDrawOrder:
            return .luaOnly
        case .borderFitGaps:
            // The whole-editor grey off the enable toggle is
            // the .focusBorder CONTAINER gate.
            return .row(.gapsAndBorders, .focusBorder, .atRest)
        case .stickyMark:
            // Ungated. The mark paints on the window, so it is
            // what survives the Space Bar going off — a gate
            // here would record a dependency that runs the
            // other way, for every reader of the census
            // (StickyMarkEditor, StickyMarkUngatedTests).
            return .row(
                .gapsAndBorders,
                .stickyWindows,
                .showMore
            )
        case .dragCornerRadius:
            return .row(.gapsAndBorders, .dragAndDrop, .showMore)
        case .dragGhostEnabled, .dragDropZoneEnabled:
            return .row(.gapsAndBorders, .dragAndDrop, .atRest)
        // Each drag column greys wholesale off its Enabled
        // toggle (DragVisualControls' outer GreyOut), so every
        // row names its column's Enabled owner; sub-rows add
        // their Border/Fill owner.
        case .dragGhostBorder, .dragGhostFill:
            return .row(
                .gapsAndBorders,
                .dragAndDrop,
                .showMore,
                gate: .setting(.borders(.dragGhostEnabled))
            )
        case .dragDropZoneBorder, .dragDropZoneFill:
            return .row(
                .gapsAndBorders,
                .dragAndDrop,
                .showMore,
                gate: .setting(.borders(.dragDropZoneEnabled))
            )
        case .dragGhostBorderColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .anyOf([
                    .borders(.dragGhostEnabled),
                    .borders(.dragGhostBorder),
                ])
            )
        case .dragGhostFillColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .anyOf([
                    .borders(.dragGhostEnabled),
                    .borders(.dragGhostFill),
                ])
            )
        case .dragGhostBorderWidth, .dragGhostBorderAlignment:
            return .row(
                .gapsAndBorders,
                .dragAndDrop,
                .showMore,
                gate: .anyOf([
                    .borders(.dragGhostEnabled),
                    .borders(.dragGhostBorder),
                ])
            )
        case .dragDropZoneBorderWidth, .dragDropZoneBorderAlignment:
            return .row(
                .gapsAndBorders,
                .dragAndDrop,
                .showMore,
                gate: .anyOf([
                    .borders(.dragDropZoneEnabled),
                    .borders(.dragDropZoneBorder),
                ])
            )
        case .dragDropZoneBorderColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .anyOf([
                    .borders(.dragDropZoneEnabled),
                    .borders(.dragDropZoneBorder),
                ])
            )
        case .dragDropZoneFillColor:
            return .row(
                .advancedColours,
                .dragAndDrop,
                .atRest,
                gate: .anyOf([
                    .borders(.dragDropZoneEnabled),
                    .borders(.dragDropZoneFill),
                ])
            )
        case .floatingColor:
            // Drawn only in the Space Bar (owner ruling
            // 2026-08-02; the gate item 10 keeps) — carried by
            // the .spaceBar CONTAINER gate. Rides the badge
            // cluster into that group's "More colors" drawer: it
            // tints a state badge, not one of the three accents
            // the bar is read by.
            return .row(.advancedColours, .spaceBar, .showMore)
        }
    }
}

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
        case .dragCornerRadius:
            return .text("drag.corner_radius")
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
        case .dragGhostBorderWidth, .dragDropZoneBorderWidth:
            return .text("drag.border_width")
        case .dragGhostBorderAlignment, .dragDropZoneBorderAlignment:
            return .text("drag.border_alignment")
        case .dragGhostFill, .dragDropZoneFill:
            return .text("drag.fill")
        case .dragGhostFillColor, .dragDropZoneFillColor:
            return .text("drag.fill")
        case .floatingColor:
            return .text("floating.color")
        }
    }
}
