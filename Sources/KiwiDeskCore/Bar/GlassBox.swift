import AppKit

/// One box's glass and tint composited in a host of their own —
/// both bars' one mint and one drop. The host is what fades (a
/// glass's own alpha shows the tint bare, #1842) and what moves:
/// a glass and its backdrop animating their own frames drift a
/// frame apart and trail (#2095). It lets presses through its
/// empty area.
final class GlassBoxHost: AppBarOverlay.FlippedView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

@MainActor
enum GlassBox {
    /// A fresh glass and tint inside a host added to `parent`.
    /// `spansParent` sizes the host to the parent (the App Bar's
    /// run-wide host, which fades and is not yet the mover);
    /// otherwise the host is the box and the glass fills it.
    static func make(
        in parent: NSView,
        spansParent: Bool
    ) -> (glass: NSView, tint: GlassBackdrop)? {
        guard let glass = GlassPlate.make() else { return nil }
        let host = GlassBoxHost(frame: spansParent ? parent.bounds : .zero)
        host.autoresizingMask = spansParent ? [.width, .height] : []
        host.wantsLayer = true
        parent.addSubview(host)
        let tint = GlassBackdrop()
        if !spansParent {
            glass.autoresizingMask = [.width, .height]
            tint.autoresizingMask = [.width, .height]
        }
        host.addSubview(glass)
        return (glass, tint)
    }

    /// The host a glass is composited in; nil for a view no box
    /// hosts, which every minted glass is.
    static func host(of glass: NSView) -> GlassBoxHost? {
        glass.superview as? GlassBoxHost
    }

    /// Takes a box out for good — glass released (#1730), tint and
    /// host removed.
    static func drop(_ glass: NSView, _ tint: GlassBackdrop?) {
        GlassPlate.release(glass)
        tint?.removeFromSuperview()
        host(of: glass)?.removeFromSuperview()
        glass.removeFromSuperview()
    }
}
