import AppKit

/// A macOS 26 Liquid Glass plate for a bar strip (#390): one
/// shared, rounded glass background under the items, tinted by the
/// bar's `background_color`. Wrapped behind a plain `NSView?` so
/// the overlays can store it without an availability annotation
/// (the concrete `NSGlassEffectView` type is macOS-26-only) and
/// drive it through one guarded entry point. Shared by both bars.
enum GlassPlate {
    /// A fresh glass plate, or nil below macOS 26.
    /// `.clear` is deliberate (QA 2026-07-19): `.regular` is the
    /// frosted, adaptive variant and read as a milky slab over
    /// the desktop; `.clear` matches the Dock's near-transparent
    /// glass. Legibility over bright wallpaper is the user's
    /// `background_color` tint — the HIG's dimming-layer lever.
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
    /// `background_color` means clear glass (no tint).
    /// `animated` eases a frame change through the caller's
    /// `NSAnimationContext` group (the App Bar moves its plate
    /// alongside its sliding tabs); fresh plates snap direct.
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
}
