import AppKit

/// macOS 26 Liquid Glass plate wrapper for bar backgrounds
/// (`NSGlassEffectView`, #390).
enum GlassPlate {
    /// Creates fresh NSGlassEffectView instance on macOS 26+.
    @MainActor
    static func make() -> NSView? {
        if #available(macOS 26, *) {
            let view = NSGlassEffectView()
            view.style = .clear
            return view
        }
        return nil
    }

    /// Configures plate frame, corner radius, and tint color.
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

    /// Embeds view into glass contentView.
    @MainActor
    static func setContent(_ view: NSView, _ content: NSView) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        if glass.contentView !== content {
            glass.contentView = content
        }
    }

    /// Detaches embedded content from glass view.
    @MainActor
    static func detach(_ view: NSView) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        glass.contentView = nil
    }

    /// Checks if glass view currently hosts the content view as its
    /// contentView.
    @MainActor
    static func holds(_ view: NSView, _ content: NSView) -> Bool {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return false }
        return glass.contentView === content
    }
}
