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
        subviews.forEach(GlassPlate.fitContent)
    }

    /// Bumped by every glide `GlassBox.place` starts, so only the
    /// latest glide's landing settles the box.
    private(set) var glideGeneration = 0
    /// Runs a landing after a delay — a timer, since a transaction
    /// completion begun inside a layout pass never fires (see
    /// `BarMotion.playWalk`); a test drains it by hand.
    var afterLanding: Landing = { delay, body in
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            body()
        }
    }
    typealias Landing = (
        TimeInterval, @escaping @MainActor () -> Void
    ) -> Void

    /// Settles `glass` once the glide just started has landed,
    /// unless a newer glide has started since (#2425).
    func settleAfterGlide(_ glass: NSView, lasting span: TimeInterval) {
        glideGeneration += 1
        let generation = glideGeneration
        afterLanding(span + Self.landingSlack) { [weak self, weak glass] in
            guard let self, let glass,
                self.glideGeneration == generation
            else { return }
            GlassBox.settle(glass)
        }
    }

    /// Past the glide's own length, so the settle never lands
    /// inside its last frames.
    static let landingSlack: TimeInterval = 0.05

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
            frame: GlassPlate.fills(glass.frame, bounds)
                ? glass.frame : bounds,
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
        let travels = animated && host.frame != .zero
        move(host, frame, travels)
        // Auto Layout can leave a growing glass at its old size
        // through an animated host move; the landing writes it.
        if travels {
            host.settleAfterGlide(
                glass,
                lasting: max(BarMotion.slide, BarMotion.shelfGlideLength)
            )
        }
    }

    /// Writes a box's glass, and the glass's content, to its
    /// host's bounds where the glass is off them: during an
    /// animated host move Auto Layout can leave a growing glass at
    /// its old size, and the next `place` keeps it there (#2425,
    /// device).
    static func settle(_ glass: NSView) {
        guard let host = host(of: glass) else { return }
        if !GlassPlate.fills(glass.frame, host.bounds) {
            glass.frame = host.bounds
        }
        GlassPlate.fitContent(glass)
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
