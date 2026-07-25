import AppKit

/// A macOS 26 Liquid Glass plate for a bar strip (#390): one
/// shared, rounded glass background under the items, tinted by the
/// bar's `fill_color`. Wrapped behind a plain `NSView?` so
/// the overlays can store it without an availability annotation
/// (the concrete `NSGlassEffectView` type is macOS-26-only) and
/// drive it through one guarded entry point. Shared by both bars.
enum GlassPlate {
    /// A fresh glass plate, or nil below macOS 26.
    /// Style is under on-device A/B (macOS 26): `.regular` is the
    /// frosted, adaptive variant that carries a real `fill_color`
    /// hue; `.clear` is near-transparent (Dock-like) and tints by
    /// luminance only. Under on-device A/B — flip the one line
    /// below between `.clear` and `.regular` to compare.
    @MainActor
    static func make() -> NSView? {
        if #available(macOS 26, *) {
            let view = NSGlassEffectView()
            view.style = .clear
            return view
        }
        return nil
    }

    /// Sizes and tints an existing plate. A fully transparent
    /// `fill_color` means clear glass (no tint).
    /// `animated` eases a frame change through the caller's
    /// `NSAnimationContext` group (the App Bar moves its plate
    /// alongside its sliding items); fresh plates snap direct.
    @MainActor
    static func update(
        _ view: NSView,
        frame: CGRect,
        cornerRadius: CGFloat,
        tintHex: String,
        animated: Bool = false
    ) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        if animated, glass.frame != .zero,
            glass.frame != frame
        {
            glass.animator().frame = frame
        } else {
            glass.frame = frame
        }
        glass.cornerRadius = cornerRadius
        let tint = NSColor(kiwiHex: tintHex)
        glass.tintColor =
            tint.alphaComponent > 0 ? tint : nil
    }

    /// Embeds `content` as the glass's `contentView` — the
    /// supported usage (Apple: "set each one's contentView …
    /// avoid placing the view behind your content as a sibling").
    /// Only this makes the tint and style actually render; a bare
    /// backdrop plate renders degraded. The glass auto-sizes the
    /// content to its own rounded bounds.
    @MainActor
    static func setContent(_ view: NSView, _ content: NSView) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        if glass.contentView !== content {
            glass.contentView = content
        }
    }

    /// Releases the embedded content so the caller can reparent it
    /// (leaving Material for Plain/Boxed).
    @MainActor
    static func detach(_ view: NSView) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        glass.contentView = nil
    }

    /// True when `content` is currently the glass's `contentView`.
    /// The reparent decision MUST use this, not `content.superview`:
    /// `NSGlassEffectView` nests its content in an internal wrapper,
    /// so `content.superview` is that wrapper, never the glass view —
    /// checking `=== glassView` there is always false, and the
    /// content would stay trapped in a hidden glass (no items/bar).
    @MainActor
    static func holds(_ view: NSView, _ content: NSView) -> Bool {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return false }
        return glass.contentView === content
    }
}
