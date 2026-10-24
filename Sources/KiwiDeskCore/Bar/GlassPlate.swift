import AppKit

/// A bar view's frame write: the view, its target, whether it
/// may travel. `BarMotion.setFrame` in production; a test hands
/// a recorder to see what a pass asked for.
typealias BarFrameMove = @MainActor (NSView, CGRect, Bool) -> Void

/// macOS 26 Liquid Glass plate wrapper for bar backgrounds
/// (`NSGlassEffectView`, #390).
enum GlassPlate {
    /// Creates fresh NSGlassEffectView instance on macOS 26+:
    /// `.clear`, or `.regular` — KiwiHub's, which the
    /// Space-switch plates wear (#1956).
    @MainActor
    static func make(regular: Bool = false) -> NSView? {
        if #available(macOS 26, *) {
            let view = NSGlassEffectView()
            view.style = regular ? .regular : .clear
            return view
        }
        return nil
    }

    /// A glass container on macOS 26+: the glass views inside its
    /// content render together, glass on glass (#1956).
    @MainActor
    static func makeContainer() -> NSView? {
        if #available(macOS 26, *) {
            return NSGlassEffectContainerView()
        }
        return nil
    }

    /// Embeds `content` into a container from `makeContainer`.
    @MainActor
    static func setContainerContent(_ view: NSView, _ content: NSView) {
        guard #available(macOS 26, *),
            let container = view as? NSGlassEffectContainerView
        else { return }
        container.contentView = content
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

    /// Embeds `content` in the glass: inside its tint where
    /// `GlassTint` has made one the glass's content, else as the
    /// content itself.
    @MainActor
    static func setContent(_ view: NSView, _ content: NSView) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView,
            !holds(glass, content)
        else { return }
        release(glass)
        guard let backdrop = glass.contentView as? GlassBackdrop else {
            glass.contentView = content
            return
        }
        backdrop.addSubview(content)
        content.frame = backdrop.bounds
    }

    /// Makes `backdrop` the glass's content, moving what the glass
    /// held inside it: the Fill draws on the material, beneath the
    /// content (#2569). A no-op once it is.
    @MainActor
    static func setBackdrop(_ view: NSView, _ backdrop: GlassBackdrop) {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView,
            glass.contentView !== backdrop
        else { return }
        let content = release(glass)
        glass.contentView = backdrop
        backdrop.frame = glass.bounds
        if let content { setContent(glass, content) }
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
            let held = glass.contentView
        else { return }
        if !fills(held.frame, glass.bounds) { held.frame = glass.bounds }
        guard held is GlassBackdrop else { return }
        for content in held.subviews
        where !fills(content.frame, held.bounds) {
            content.frame = held.bounds
        }
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
    /// `GlassPlate` takes it. A tint stays the glass's content.
    @MainActor
    @discardableResult
    static func release(_ view: NSView) -> NSView? {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView,
            let held = glass.contentView
        else { return nil }
        if held is GlassBackdrop {
            let content = held.subviews.first
            content?.removeFromSuperview()
            content?.translatesAutoresizingMaskIntoConstraints = true
            return content
        }
        glass.contentView = nil
        held.translatesAutoresizingMaskIntoConstraints = true
        return held
    }

    /// Whether the glass hosts `content`, directly or inside its
    /// tint.
    @MainActor
    static func holds(_ view: NSView, _ content: NSView) -> Bool {
        guard #available(macOS 26, *),
            let glass = view as? NSGlassEffectView,
            let held = glass.contentView
        else { return false }
        return held === content
            || (held is GlassBackdrop && content.superview === held)
    }
}
