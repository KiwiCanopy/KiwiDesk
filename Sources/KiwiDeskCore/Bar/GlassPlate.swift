import AppKit

/// A bar view's frame write: the view, its target, whether it
/// may travel. `BarMotion.setFrame` in production; a test hands
/// a recorder to see what a pass asked for.
typealias BarFrameMove = @MainActor (NSView, CGRect, Bool) -> Void

/// macOS 26 Liquid Glass plate wrapper for bar backgrounds
/// (`NSGlassEffectView`, #390).
enum GlassPlate {
    /// Creates fresh `.clear` NSGlassEffectView instance on macOS
    /// 26+.
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
        cornerRadius: CGFloat
    ) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        // Never travels: a gliding glass rides its `GlassBox` host
        // (#2095), and an equal write would cancel its follow.
        if glass.frame != frame { glass.frame = frame }
        glass.cornerRadius = cornerRadius
        fitContent(glass)
    }

    /// Embeds view into glass contentView.
    @MainActor
    static func setContent(_ view: NSView, _ content: NSView) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView
        else { return }
        if glass.contentView !== content {
            release(glass)
            glass.contentView = content
        }
    }

    /// Writes a glass's content to the glass's bounds where it is
    /// off by more than the backing's rounding, after every resize
    /// of the glass — `update` and the box host's: the glass's own
    /// layout left a Space chip at its old length inside a resized
    /// box (#2425, device).
    @MainActor
    static func fitContent(_ view: NSView) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView,
            let content = glass.contentView,
            !fills(content.frame, glass.bounds)
        else { return }
        content.frame = glass.bounds
    }

    /// Whether `frame` already fills `bounds`: each edge within
    /// half a point, the most the backing's rounding moves one.
    nonisolated static func fills(
        _ frame: CGRect,
        _ bounds: CGRect
    ) -> Bool {
        abs(frame.minX - bounds.minX) <= 0.5
            && abs(frame.minY - bounds.minY) <= 0.5
            && abs(frame.maxX - bounds.maxX) <= 0.5
            && abs(frame.maxY - bounds.maxY) <= 0.5
    }

    /// Takes content out of a glass with frame layout restored,
    /// which hosting turned off (#1730); every exit through
    /// `GlassPlate` takes it.
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
