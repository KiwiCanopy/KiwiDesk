import AppKit

/// A view an item seats in its box's host above the glass
/// (`GlassBox.seatStrokes`, #2595): the item frames it, and the
/// host sizes it never. It takes no press — its `hitTest` answers
/// nil and the item answers its own — since outside the item a
/// hit on it would reach no item.
@MainActor
protocol GlassBoxRider: NSView {}

/// One box's glass and tint composited in a host of their own —
/// every travelling glass's one mint, place and drop — with the
/// hosted item's riders above the glass. The host is
/// what fades (a glass's own alpha shows the tint bare, #1842) and
/// what moves: a glass and its backdrop animating their own frames
/// drift a frame apart and trail (#2095). It lets presses through
/// its empty area.
final class GlassBoxHost: NSView {
    override var isFlipped: Bool { true }

    /// A hosted glass's one frame writer (#2878): every new size
    /// the host takes writes its pair, never a rider, to its bounds
    /// exactly. Autoresizing left a glass at the fused plate's
    /// width when the host shrank (#2388, device).
    override func setFrameSize(_ newSize: NSSize) {
        let resized = newSize != frame.size
        super.setFrameSize(newSize)
        guard resized else { return }
        for view in subviews
        where view.frame != bounds && !(view is GlassBoxRider) {
            view.frame = bounds
        }
        subviews.filter { !($0 is GlassBoxRider) }
            .forEach(GlassPlate.fitContent)
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
    /// pair fills: the host writes it on every resize, and no
    /// autoresizing mask lets the layout engine derive it (#2878).
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
        glass.autoresizingMask = []
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

    /// Lays a box out at `frame`: rounds the glass and paints its
    /// tint, then moves the host, the one view that travels
    /// (#2095) and the glass's one frame writer
    /// (`GlassBoxHost.setFrameSize`, #2878); a box resizes only by
    /// resizing its host. A fresh host lands rather than gliding
    /// from nowhere. `visible` false hides the whole
    /// box, which still takes its slot; `fill` is the Fill its tint
    /// paints, on the glass or, `behind`, beneath it.
    static func place(
        _ glass: NSView,
        tint: GlassBackdrop,
        at frame: CGRect,
        cornerRadius: CGFloat,
        fill: GlassFill,
        edge: AppBarEdge,
        visible: Bool,
        animated: Bool,
        behind: Bool = false,
        move: BarFrameMove = BarMotion.setFrame(_:to:animated:)
    ) {
        guard let host = host(of: glass) else { return }
        host.isHidden = !visible
        GlassPlate.round(glass, cornerRadius: cornerRadius)
        if behind {
            GlassTint.applyBehind(
                tint,
                below: glass,
                cornerRadius: cornerRadius,
                fill: fill,
                edge: edge
            )
        } else {
            GlassTint.apply(
                tint,
                in: glass,
                cornerRadius: cornerRadius,
                fill: fill,
                edge: edge
            )
        }
        move(host, frame, animated && host.frame != .zero)
    }

    /// Seats an item's stroke stack in its box's host above the
    /// glass while a glass hosts `item`, since the glass's
    /// key-window rim draws over its content (#2595), and in the
    /// item otherwise: the first rider beneath the item's content,
    /// the rest above it, in order. The item calls it as it moves
    /// and frames the riders in its own coordinates, the host's
    /// while it fills it.
    static func seatStrokes(
        _ riders: [GlassBoxRider],
        of item: NSView
    ) {
        let parent = host(holding: item) ?? item
        guard riders.contains(where: { $0.superview !== parent })
        else { return }
        for (index, rider) in riders.enumerated() {
            if index == 0, parent === item {
                item.addSubview(rider, positioned: .below, relativeTo: nil)
            } else {
                parent.addSubview(rider)
            }
        }
    }

    /// The host whose glass holds `item`, in its tint or directly.
    /// The glass nests its content in views of its own, so the
    /// host is found by ancestry.
    static func host(holding item: NSView) -> GlassBoxHost? {
        var view = item.superview
        while let ancestor = view {
            if let host = ancestor as? GlassBoxHost {
                let holds = host.subviews.contains {
                    GlassPlate.holds($0, item)
                }
                return holds ? host : nil
            }
            view = ancestor.superview
        }
        return nil
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
