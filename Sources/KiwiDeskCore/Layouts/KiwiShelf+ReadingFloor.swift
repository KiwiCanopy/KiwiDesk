import CoreGraphics

/// The floor a READING surface's fade keeps (#2569 ▸ Ruling): the
/// hover peek and the overflow mark's list fade like the bar, but
/// their far end never drops below the share that holds their worst
/// ink at `readingInkFloor` over a white or a black wallpaper.
extension KiwiShelf {
    /// Contrast a reading surface's worst ink holds at the fade's
    /// far end. Below `idleInkFloor` on purpose: that floor is for
    /// dimmed idle ink on a bar, and the owner judged 1.5 readable
    /// on real `.clear` glass over a white window for all ten
    /// bundled palettes (2026-10-24); the model composites over a
    /// flat wallpaper and leaves out the glass's own milky layer,
    /// so it reads the screen pessimistically. Retune it on real
    /// glass over white AND black, never from the model alone.
    public static let readingInkFloor = 1.5

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
    /// holds `readingInkFloor`, or `idleInkFloor` under Increase
    /// Contrast.
    public func readingGlassFill(increaseContrast: Bool) -> GlassFill {
        let floor = increaseContrast ? Self.idleInkFloor : Self.readingInkFloor
        return GlassFill(
            hex: fillColor,
            fade: fillFade,
            minShare: readingShare(holding: floor)
        )
    }

    /// The least share of the capped anchor at which every reading
    /// ink holds `floor`: 1 where the anchor itself cannot, 0 where
    /// the Fill does not parse.
    func readingShare(holding floor: Double) -> CGFloat {
        guard let rgba = DragVisual.parseHex(fillColor) else { return 0 }
        let anchor = min(CGFloat(rgba.alpha), GlassTint.maxAlpha)
        func holds(_ share: CGFloat) -> Bool {
            let ground = fill(cappedAt: anchor * share)
            return readingInks.allSatisfy { pair in
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
