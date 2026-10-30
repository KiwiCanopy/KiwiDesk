import AppKit

/// The floor a READING surface's fade keeps (#2569 ▸ Ruling): the
/// hover peek, the overflow mark's list, KiwiHub and the cue plates
/// fade like the bar, but their far end never drops below the share
/// that holds their worst ink at `readingFloor` over a white or a
/// black wallpaper.
extension KiwiShelf {
    /// Default contrast a reading surface's worst ink holds at the
    /// fade's far end (`readingContrast`). Never an alias of
    /// `idleInkFloor`: that floor guards dimmed idle ink on a bar.
    /// Measured 2026-10-30: at 1.5 the tinted default look
    /// with macOS's Liquid Glass slider at its minimum failed over
    /// a white window (model ~1.9:1). Retune on real glass over
    /// white AND black, never from the model alone.
    public static let readingInkFloor = 2.2

    /// The floor under Increase Contrast, never below the user's
    /// own (owner, 2026-10-30): the default look's Fill holds it
    /// only at its anchor, so it paints flat.
    public static let increasedReadingInkFloor = 3.0

    /// Bounds of `readingContrast` (#2569): 1 is no floor, the full
    /// fade; a ratio the Fill cannot reach paints it flat.
    public static let readingContrastRange: ClosedRange<Double> = 1...4.5

    /// `value` within `readingContrastRange`.
    public static func clampReadingContrast(_ value: Double) -> Double {
        min(
            max(value, readingContrastRange.lowerBound),
            readingContrastRange.upperBound
        )
    }

    /// The contrast the reading fades hold: `readingContrast`,
    /// raised to `increasedReadingInkFloor` under Increase Contrast.
    public func readingFloor(increaseContrast: Bool) -> Double {
        increaseContrast
            ? max(readingContrast, Self.increasedReadingInkFloor)
            : readingContrast
    }

    /// The inks the peek draws, each over the layer it sits on:
    /// titles, the header, a hovered row on its fill.
    var readingInks: [(ink: String, layer: String?)] {
        [
            (itemColor, nil),
            (peekHeaderColor, nil),
            (hoverItemColor, hoverFillColor),
        ]
    }

    /// The peek's Fill: the shelf's fade, floored at the share that
    /// holds `readingFloor(increaseContrast:)`.
    public func readingGlassFill(increaseContrast: Bool) -> GlassFill {
        readingGlassFill(inks: readingInks, increaseContrast: increaseContrast)
    }

    /// KiwiHub's and the cue plates' inks: the look's three
    /// (`panelInk`) and KiwiHub's hover row on its fill.
    func panelInks(
        increaseContrast: Bool
    ) -> [(ink: String, layer: String?)] {
        let ink = panelInk(increaseContrast: increaseContrast)
        let hover = panelHighlight
        return [
            (ink.primary, nil), (ink.secondary, nil), (ink.tertiary, nil),
            (hover.hoverInk, hover.hover),
        ]
    }

    /// KiwiHub's and the cue plates' Fill under "Tint KiwiHub and
    /// plates": the shelf's fade, floored for their inks.
    public func panelGlassFill(increaseContrast: Bool) -> GlassFill {
        readingGlassFill(
            inks: panelInks(increaseContrast: increaseContrast),
            increaseContrast: increaseContrast
        )
    }

    /// The shelf's Fill and fade, floored where `inks` need it.
    func readingGlassFill(
        inks: [(ink: String, layer: String?)],
        increaseContrast: Bool
    ) -> GlassFill {
        GlassFill(
            hex: fillColor,
            fade: fillFade,
            minShare: readingShare(
                holding: readingFloor(increaseContrast: increaseContrast),
                inks: inks
            )
        )
    }

    /// The least share of the capped anchor at which every reading
    /// ink holds `floor`: 1 where the anchor itself cannot, 0 where
    /// the Fill does not parse.
    func readingShare(
        holding floor: Double,
        inks: [(ink: String, layer: String?)]
    ) -> CGFloat {
        guard let rgba = DragVisual.parseHex(fillColor) else { return 0 }
        let anchor = min(CGFloat(rgba.alpha), GlassTint.maxAlpha)
        func holds(_ share: CGFloat) -> Bool {
            let ground = fill(cappedAt: anchor * share)
            return inks.allSatisfy { pair in
                (worstContrast(pair.ink, nil, on: ground, beneath: pair.layer)
                    ?? 0) >= floor
            }
        }
        guard anchor > 0, holds(1) else { return 1 }
        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0..<20 {
            let mid = (low + high) / 2
            if holds(mid) { high = mid } else { low = mid }
        }
        return high
    }
}

extension KiwiShelf {
    /// The far end a KiwiHub selection or hover fill keeps at the
    /// strongest fade, as a share of its top (#2721, ui-designer):
    /// the panel's floor guards the panel's inks, and a fill
    /// carries its own.
    static let highlightFloorShare: CGFloat = 0.4

    /// The far end of KiwiHub's selection and hover fills: Fill
    /// fade's own share, never below `highlightFloorShare`, and
    /// raised to the share at which each fill's ink holds the
    /// reading floor (`readingFloor(increaseContrast:)`) over the
    /// panel's both ends (`HighlightFadeContrastTests`).
    public func highlightFadeShare(increaseContrast: Bool) -> CGFloat {
        let floor = readingFloor(increaseContrast: increaseContrast)
        let base = max(
            GlassTint.farShare(fade: fillFade),
            Self.highlightFloorShare
        )
        guard let rgba = DragVisual.parseHex(fillColor) else { return base }
        let anchor = min(CGFloat(rgba.alpha), GlassTint.maxAlpha)
        let panel = panelGlassFill(increaseContrast: increaseContrast)
        let far = max(GlassTint.farShare(fade: panel.fade), panel.minShare)
        let grounds = [fill(cappedAt: anchor), fill(cappedAt: anchor * far)]
        let paint = panelHighlight
        let pairs = [
            (paint.selectionInk, paint.selection),
            (paint.hoverInk, paint.hover),
        ]
        func holds(_ share: CGFloat) -> Bool {
            grounds.allSatisfy { ground in
                pairs.allSatisfy { ink, layer in
                    let ratio = worstContrast(
                        ink,
                        nil,
                        on: ground,
                        beneath: Self.hex(layer, atShare: share)
                    )
                    return (ratio ?? 0) >= floor
                }
            }
        }
        guard !holds(base) else { return base }
        guard holds(1) else { return 1 }
        var low = base
        var high: CGFloat = 1
        for _ in 0..<20 {
            let mid = (low + high) / 2
            if holds(mid) { high = mid } else { low = mid }
        }
        return high
    }
}
