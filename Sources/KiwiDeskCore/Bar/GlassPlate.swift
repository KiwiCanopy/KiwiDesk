import AppKit

/// A bar view's frame write: the view, its target, whether it
/// may travel. `BarMotion.setFrame` in production; a test hands
/// a recorder to see what a pass asked for.
typealias BarFrameMove = @MainActor (NSView, CGRect, Bool) -> Void

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

    /// Configures plate frame and corner radius. The plate takes no
    /// colour — that is `GlassTint`'s, and the reason `tintColor`
    /// cannot carry it is in `docs/design-decisions.md` ▸ Liquid
    /// Glass (#1297).
    @MainActor
    static func update(
        _ view: NSView,
        frame: CGRect,
        cornerRadius: CGFloat,
        animated: Bool = false,
        move: BarFrameMove = BarMotion.setFrame(_:to:animated:)
    ) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        move(glass, frame, animated)
        glass.cornerRadius = cornerRadius
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

    /// Hands the glass's content back as an ordinary frame-laid
    /// view, returning it: hosting turned its
    /// `translatesAutoresizingMaskIntoConstraints` off, and left off
    /// the next layout pass places it at its intrinsic size in the
    /// corner (#1730). The one way content leaves a glass.
    @MainActor
    @discardableResult
    static func release(_ view: NSView) -> NSView? {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView,
            let content = glass.contentView
        else { return nil }
        glass.contentView = nil
        content.translatesAutoresizingMaskIntoConstraints = true
        return content
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
