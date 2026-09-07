import AppKit

/// Colored backdrop behind Liquid Glass surfaces (`NSGlassEffectView`,
/// #408), and the one place a stored Fill becomes a rendered colour on
/// glass (#1297).
enum GlassTint {
    /// Ceiling on the backdrop's alpha — a floor on how much
    /// refraction survives, not a legibility budget. A Fill at or
    /// below it renders exactly as picked; only what cannot render
    /// as glass is bent.
    ///
    /// **Measured and KEPT at 0.65, 2026-09-07, macOS 26.6.2**
    /// (#1297). The retune the issue expected was not needed: the
    /// plate read as a slab because `tintColor` was dimming it
    /// beside this cap, and closing that bypass alone moved the
    /// composite over a bright busy ground from RGB ~(104,106,95)
    /// to ~(122,124,110) — the ground's structure legible through
    /// it, which is the whole of what "reads as glass" meant here.
    ///
    /// Every bundled palette ships its bar fills at `…B3` (0.70),
    /// so on a default install this cap is what the plate actually
    /// renders at — the value a retune moves for most users.
    ///
    /// **What binds the number is the ink, not the blur.** A bar's
    /// item colour is fixed palette hex with no vibrancy path
    /// (`docs/design-decisions.md` ▸ App Bar), so this plate is the
    /// legibility floor. Against `#EAF3EE` over the brightest
    /// patches of a busy ground: 0.65 holds ~3.3:1 and 0.50 falls
    /// to ~2.7:1, for very little further refraction — and this
    /// repo already refused a pairing at ~3.3:1 as too thin at
    /// small sizes (the systemGray badge, #955). So lowering it
    /// spends what the ink has left and buys nearly nothing.
    ///
    /// Retune it over a BLACK and a WHITE wallpaper, both bars,
    /// boxed and plain, and measure the ink against the composite
    /// rather than eyeballing the blur — a flat wallpaper shows no
    /// refraction at any alpha, so a ground with structure in it is
    /// the only instrument that answers. Never subtract from the
    /// alpha a palette happens to ship: that measures the palette.
    static let maxAlpha: CGFloat = 0.65

    /// The colour a stored Fill renders as on glass — clamped to
    /// `maxAlpha`, `nil` where the Fill is transparent or the OS
    /// draws no glass.
    ///
    /// **Private, and that is the guard.** Every surface reaches a
    /// colour through `apply`, so the compiler holds what a scan
    /// would otherwise have to police. A sibling channel taking the
    /// raw Fill beside this clamp is what #1297 was — `GlassPlate`
    /// set `tintColor` that way.
    @MainActor
    private static func rendered(_ hex: String) -> NSColor? {
        // The one availability authority, not a second `#available`
        // beside it: nothing here touches a macOS 26 API, so the
        // check is policy rather than the compiler's.
        guard AppBarStyle.glassAvailable else { return nil }
        let fill = NSColor(kiwiHex: hex)
        guard fill.alphaComponent > 0 else { return nil }
        return fill.alphaComponent > maxAlpha
            ? fill.withAlphaComponent(maxAlpha) : fill
    }

    /// Positions and colors the backdrop beneath the target glass,
    /// hiding it where the Fill reaches no colour. It takes the Fill
    /// rather than a colour so the cap cannot be walked around at a
    /// call site (#1297).
    @MainActor
    static func apply(
        _ backdrop: NSView,
        below glass: NSView,
        frame: CGRect,
        cornerRadius: CGFloat,
        hex: String,
        animated: Bool = false
    ) {
        guard let color = rendered(hex) else {
            backdrop.isHidden = true
            return
        }
        backdrop.wantsLayer = true
        if let parent = glass.superview, backdrop.superview !== parent {
            parent.addSubview(
                backdrop,
                positioned: .below,
                relativeTo: glass
            )
        }
        backdrop.isHidden = false
        BarMotion.setFrame(backdrop, to: frame, animated: animated)
        backdrop.layer?.cornerRadius = cornerRadius
        backdrop.layer?.backgroundColor = color.cgColor
    }
}
