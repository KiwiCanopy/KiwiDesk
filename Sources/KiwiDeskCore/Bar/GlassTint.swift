import AppKit

/// Colored backdrop behind Liquid Glass surfaces (`NSGlassEffectView`, #408).
enum GlassTint {
    /// Render cap for glass backdrop opacity to preserve refraction (#408).
    static let maxAlpha: CGFloat = 0.65

    /// Checks if glass tint backdrop is enabled for the given color hex.
    @MainActor
    static func wanted(_ hex: String) -> Bool {
        guard #available(macOS 26, *) else { return false }
        return NSColor(kiwiHex: hex).alphaComponent > 0
    }

    /// Positions and colors backdrop view beneath target glass element.
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
