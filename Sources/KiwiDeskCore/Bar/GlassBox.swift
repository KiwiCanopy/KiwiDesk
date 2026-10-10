import AppKit

/// One box's glass and tint composited in a host of their own —
/// every travelling glass's one mint, place and drop. The host is
/// what fades (a glass's own alpha shows the tint bare, #1842) and
/// what moves: a glass and its backdrop animating their own frames
/// drift a frame apart and trail (#2095). It lets presses through
/// its empty area.
final class GlassBoxHost: AppBarOverlay.FlippedView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

@MainActor
enum GlassBox {
    /// A fresh glass and tint inside a box-sized host added to
    /// `parent` — beneath `sibling` where one is named — that the
    /// pair fills by autoresizing.
    static func make(
        in parent: NSView,
        below sibling: NSView? = nil
    ) -> (glass: NSView, tint: GlassBackdrop)? {
        guard let glass = GlassPlate.make() else { return nil }
        let host = GlassBoxHost(frame: .zero)
        host.wantsLayer = true
        if let sibling, sibling.superview === parent {
            parent.addSubview(host, positioned: .below, relativeTo: sibling)
        } else {
            parent.addSubview(host)
        }
        let tint = GlassBackdrop()
        glass.autoresizingMask = [.width, .height]
        tint.autoresizingMask = [.width, .height]
        host.addSubview(glass)
        return (glass, tint)
    }

    /// The host a glass is composited in; nil for a view no box
    /// hosts.
    static func host(of glass: NSView) -> GlassBoxHost? {
        glass.superview as? GlassBoxHost
    }

    /// Where a box stands in its host's parent: the host's frame.
    static func frame(of glass: NSView) -> CGRect {
        host(of: glass)?.frame ?? glass.frame
    }

    /// Lays a box out at `frame`: the pair takes the host's CURRENT
    /// bounds, then the host — the one view that travels (#2095) —
    /// moves; AppKit steps a travelling frame and autoresizes the
    /// pair at each step, and an equal write is skipped so it never
    /// cancels that follow. `hex` nil hides the tint. A fresh host
    /// lands rather than gliding from nowhere.
    static func place(
        _ glass: NSView,
        tint: GlassBackdrop,
        at frame: CGRect,
        cornerRadius: CGFloat,
        hex: String?,
        edge: AppBarEdge,
        animated: Bool,
        move: @escaping BarFrameMove = BarMotion.setFrame(_:to:animated:)
    ) {
        guard let host = host(of: glass) else { return }
        let fill: BarFrameMove = { view, target, _ in
            if view.frame != target { move(view, target, false) }
        }
        let bounds = host.bounds
        GlassPlate.update(
            glass,
            frame: bounds,
            cornerRadius: cornerRadius,
            move: fill
        )
        if let hex {
            GlassTint.apply(
                tint,
                below: glass,
                frame: bounds,
                cornerRadius: cornerRadius,
                hex: hex,
                edge: edge,
                move: fill
            )
        } else {
            tint.isHidden = true
        }
        move(host, frame, animated && host.frame != .zero)
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
