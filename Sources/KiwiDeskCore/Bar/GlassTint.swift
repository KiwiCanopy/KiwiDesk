import AppKit

/// A solid colored backdrop for a Liquid Glass surface (#408). On
/// macOS 26.5.2 an `NSGlassEffectView`'s own `tintColor` reads
/// near-colorless — it shifts luminance, not hue, so a "brown
/// glass" and a "blue glass" look the same frosted grey. So instead
/// of fighting the tint API, a solid colored view sits directly
/// *behind* the glass; the glass refracts / samples it and adopts
/// that hue — the same way the Dock and Control Center tint their
/// glass. The backdrop supplies only color; the glass keeps its
/// blur and refraction intact. Below macOS 26 there is no glass, so
/// there is no backdrop (the solid shape carries the color itself).
/// Shared by both bars, one per glass surface (each box, the plate,
/// each arrow / the front segment).
enum GlassTint {
    /// The most opaque a backdrop is allowed to render (#408): above
    /// this the solid color crowds out the blur / refraction and the
    /// "glass" reads as a flat colored plate — the pointless case.
    /// A *render* cap, not a stored-value clamp: the `fill_color`
    /// keeps whatever alpha the user set (GUI or Lua, used in full by
    /// the solid boxed/plain shapes and when glass is off); only the
    /// glass backdrop is held translucent so glass always looks like
    /// glass. Below it any alpha is honored, including 0 (clear
    /// glass). Chosen on-device (macOS 26.5.2) — the top of the
    /// legible tinted-glass band; the sweet spot sits ~35–50 %.
    static let maxAlpha: CGFloat = 0.65

    /// Whether a tint backdrop should be drawn: only on macOS 26
    /// (where glass renders at all) and only for a visible Fill —
    /// a fully transparent Fill means clear, untinted glass.
    @MainActor
    static func wanted(_ hex: String) -> Bool {
        guard #available(macOS 26, *) else { return false }
        return NSColor(kiwiHex: hex).alphaComponent > 0
    }

    /// Sizes and tints `backdrop`, placing it just below `glass` in
    /// the glass's own superview, at the glass's `frame` and
    /// `cornerRadius`, filled with `hex`. `animated` eases the frame
    /// change so the backdrop tracks an animated glass plate instead
    /// of lagging a color edge into view. The caller owns the view
    /// (creating and storing it) so per-box backdrops can live in a
    /// pool parallel to the glass boxes.
    @MainActor
    static func apply(
        _ backdrop: NSView,
        below glass: NSView,
        frame: CGRect,
        cornerRadius: CGFloat,
        hex: String,
        animated: Bool = false
    ) {
        backdrop.wantsLayer = true
        if let parent = glass.superview, backdrop.superview !== parent {
            parent.addSubview(
                backdrop,
                positioned: .below,
                relativeTo: glass
            )
        }
        backdrop.isHidden = false
        if animated, backdrop.frame != .zero,
            backdrop.frame != frame
        {
            backdrop.animator().frame = frame
        } else {
            backdrop.frame = frame
        }
        backdrop.layer?.cornerRadius = cornerRadius
        // Cap the backdrop's opacity so the glass keeps its blur;
        // the stored Fill is untouched (see `maxAlpha`).
        let fill = NSColor(kiwiHex: hex)
        let capped =
            fill.alphaComponent > maxAlpha
            ? fill.withAlphaComponent(maxAlpha) : fill
        backdrop.layer?.backgroundColor = capped.cgColor
    }
}
