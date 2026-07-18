import AppKit

/// A macOS 26 Liquid Glass plate for a bar strip (#390): one
/// shared, rounded glass background under the items, tinted by the
/// bar's `background_color`. Wrapped behind a plain `NSView?` so
/// the overlays can store it without an availability annotation
/// (the concrete `NSGlassEffectView` type is macOS-26-only) and
/// drive it through one guarded entry point. Shared by both bars.
enum GlassPlate {
    /// A fresh glass plate, or nil below macOS 26.
    @MainActor
    static func make() -> NSView? {
        if #available(macOS 26, *) {
            let view = NSGlassEffectView()
            view.style = .regular
            return view
        }
        return nil
    }

    /// Sizes and tints an existing plate. A fully transparent
    /// `background_color` means clear glass (no tint).
    @MainActor
    static func update(
        _ view: NSView,
        frame: CGRect,
        cornerRadius: CGFloat,
        tintHex: String
    ) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        glass.frame = frame
        glass.cornerRadius = cornerRadius
        let tint = NSColor(kiwiHex: tintHex)
        glass.tintColor =
            tint.alphaComponent > 0 ? tint : nil
    }
}
