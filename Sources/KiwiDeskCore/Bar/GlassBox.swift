import AppKit

/// One box's glass and tint composited in a host of their own —
/// every travelling glass's one mint, place and drop. The host is
/// what fades (a glass's own alpha shows the tint bare, #1842) and
/// what moves: a glass and its backdrop animating their own frames
/// drift a frame apart and trail (#2095). It lets presses through
/// its empty area.
final class GlassBoxHost: NSView {
    override var isFlipped: Bool { true }

    /// The host writes its pair to every size it takes, glass and
    /// tint alike: autoresizing left a hosted glass at the fused
    /// plate's width when the host shrank (#2388, device).
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        for view in subviews where view.frame != bounds {
            view.frame = bounds
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

@MainActor
enum GlassBox {
    /// A fresh glass and tint inside a box-sized host added to
    /// `parent` — beneath `sibling` where one is named — that the
    /// pair fills: the host writes it on every resize. The masks
    /// stay as the device-checked shape and are not relied on.
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
    /// bounds — the one write a host whose size stays the same gets
    /// — then the host, the one view that travels (#2095), moves
    /// and writes the pair to each size it takes
    /// (`GlassBoxHost.setFrameSize`). A fresh host lands rather
    /// than gliding from nowhere. `visible` false hides the whole
    /// box, which still takes its slot; `hex` is the Fill its tint
    /// paints.
    static func place(
        _ glass: NSView,
        tint: GlassBackdrop,
        at frame: CGRect,
        cornerRadius: CGFloat,
        hex: String,
        edge: AppBarEdge,
        visible: Bool,
        animated: Bool,
        move: BarFrameMove = BarMotion.setFrame(_:to:animated:)
    ) {
        guard let host = host(of: glass) else { return }
        host.isHidden = !visible
        let bounds = host.bounds
        // A glass Auto Layout rounded to the backing is left there:
        // rewriting it stranded it at its old size (#2388, device).
        GlassPlate.update(
            glass,
            frame: fills(glass.frame, bounds) ? glass.frame : bounds,
            cornerRadius: cornerRadius
        )
        GlassTint.apply(
            tint,
            below: glass,
            frame: bounds,
            cornerRadius: cornerRadius,
            hex: hex,
            edge: edge
        )
        move(host, frame, animated && host.frame != .zero)
    }

    /// Whether a hosted glass at `frame` already fills `bounds`: each
    /// edge within half a point, the most the backing's rounding
    /// moves one.
    nonisolated static func fills(
        _ frame: CGRect,
        _ bounds: CGRect
    ) -> Bool {
        abs(frame.minX - bounds.minX) <= 0.5
            && abs(frame.minY - bounds.minY) <= 0.5
            && abs(frame.maxX - bounds.maxX) <= 0.5
            && abs(frame.maxY - bounds.maxY) <= 0.5
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
