/// Borders, sticky/floating marks and drag visuals census slice (#754).

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
    case stickyDesktopReach = "settings.stickyStyle.desktopReach"
    case floatingMark = "settings.floatingStyle.mark"
    case dragDropZoneEnabled = "settings.dragDropZone.enabled"
    case dragGhostEnabled = "settings.dragGhost.enabled"
    case floatingColor = "settings.floatingStyle.color"
    case pocketColor = "settings.pocketStyle.color"
}

extension BordersKey {
    var placement: SettingPlacement {
        switch self {
        case .borderEnabled:
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .atRest,
                exemptFromContainerGate: true
            )
        case .borderWidth, .borderCorner:
            // Every window stroke's (#1742).
            return .row(.gapsAndBorders, .borders, .atRest)
        case .borderFitGapsExtraSpacing, .borderFitGaps:
            // In the Gaps card since #1360 — it writes the GAPS —
            // greyed with its reason while the border it reads
            // is off.
            return .row(
                .gapsAndBorders,
                .gaps,
                .atRest,
                gate: .setting(.borders(.borderEnabled))
            )
        case .borderFocusedColor:
            return .row(
                .coloursAndMotion,
                .accent,
                .showMore,
                gate: .setting(.borders(.borderEnabled))
            )
        case .borderUnfocusedEnabled, .borderGlow:
            return .row(.gapsAndBorders, .focusBorder, .atRest)
        case .borderGlowSizeAuto:
            // Greys with the slider it governs: neither has an
            // effect while the glow is off (#1377).
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .atRest,
                gate: .setting(.borders(.borderGlow))
            )
        case .borderUnfocusedColor:
            return .row(
                .coloursAndMotion,
                .windowMarks,
                .showMore,
                gate: .anyOf([
                    .borders(.borderEnabled),
                    .borders(.borderUnfocusedEnabled),
                ])
            )
        case .stickyColor, .floatingColor, .pocketColor:
            // Each paints on the window, so none takes the Space
            // Bar's gate (StickyMarkUngatedTests, #1799).
            return .row(.coloursAndMotion, .windowMarks, .showMore)
        case .borderGlowSize:
            return .row(
                .gapsAndBorders,
                .focusBorder,
                .atRest,
                gate: .anyOf([
                    .borders(.borderGlow),
                    .borders(.borderGlowSizeAuto),
                ])
            )
        case .borderDrawOrder:
            return .luaOnly
        case .stickyMark, .floatingMark:
            // Ungated (StickyMarkUngatedTests).
            return .row(
                .gapsAndBorders,
                .stickyWindows,
                .atRest
            )
        case .stickyDesktopReach:
            // HIDDEN without the bridge (#1145) — the
            // liquid-glass shape, not a grey.
            return .row(
                .gapsAndBorders,
                .stickyWindows,
                .atRest,
                gate: .runtime(.desktopBridgeAbsent)
            )
        case .dragGhostEnabled, .dragDropZoneEnabled:
            return .row(.gapsAndBorders, .dragAndDrop, .atRest)
        }
    }
}
