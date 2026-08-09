/// Borders, sticky/floating marks and drag visuals
/// (`BorderStyle`, `StickyStyle`, `FloatingStyle`,
/// `DragGhost`, `DragDropZone`).
///
/// The three strokes KiwiDesk draws — the focus ring, the drag
/// ghost and the drop zone — share one width and one corner
/// decision, and the GUI asks each of them exactly once, in the
/// `.borders` card (#754). Everything that would ask a second
/// time left the GUI there (GUI_REMOVED_2026-08): both per-stroke
/// alignments, both per-stroke widths, and the drag pair's
/// numeric corner radius. Every one of those Lua verbs stays
/// open and unclamped.

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
        // The two shared decisions, lifted out of the sections
        // they used to sit in (#754). Each is one master row
        // that WRITES all three strokes, so it belongs to no
        // one section any more. Never inside `.focusBorder`:
        // the ring going off must not grey a control the drag
        // visuals read. Both draw as lead controls of the card
        // with no disclosure over them, hence `.atRest`.
        case .borderWidth, .borderCorner:
            return .row(.gapsAndBorders, .borders, .atRest)
        case .borderFitGapsExtraSpacing:
            // Behind Show more with the glow rows: a parameter
            // to one action, below the ring's own shape.
            return .row(.gapsAndBorders, .focusBorder, .showMore)
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
        case .borderUnfocusedEnabled, .borderGlow,
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
            // other way, for every reader of the census. The
            // row is drawn by StickyMarkEditor and held ungated
            // by StickyMarkUngatedTests; neither reads this.
            return .row(
                .gapsAndBorders,
                .stickyWindows,
                .showMore
            )
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
        case .dragGhostBorderAlignment,
            .dragDropZoneBorderAlignment,
            .dragGhostBorderWidth,
            .dragDropZoneBorderWidth,
            .dragCornerRadius:
            // GUI_REMOVED_2026-08 (#754). Each of these asks a
            // question the Borders card already asks once for
            // all three strokes, or one it cannot ask of all
            // three at all: the ring has no alignment concept,
            // and it has no corner RADIUS either — collapsing a
            // 0–40 pt slider into its two-value corner style
            // rendered 1 pt and 40 pt identically. The masters
            // WRITE these values; nothing offers a second,
            // per-stroke surface for them. All five verbs stay
            // Lua-settable per stroke and unclamped. A
            // surfaceless row carries no gate.
            return .luaOnly
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
