import AppKit
import Testing

@testable import KiwiDeskCore

/// A gliding box's glass is written to its host's size at once and
/// its layers follow the host's own animation, so glass and host
/// share one clock; where the glass is not the measured shape the
/// follow adds nothing and the landing settle repairs the frame
/// (#2878 ruling amendment, 2026-11-14). Main-actor spend: two
/// small windows and a handful of glass layouts per test.
@Suite("Glass box follow", .serialized)
@MainActor
struct GlassBoxFollowTests {
    private struct Rig {
        let window: NSWindow
        let glass: NSView
        let tint: GlassBackdrop
        let host: GlassBoxHost
    }

    private func rig(behind: Bool = false) throws -> Rig? {
        guard #available(macOS 26, *) else { return nil }
        let window = NSWindow(
            contentRect: CGRect(x: 200, y: 400, width: 400, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let root = NSView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 60)
        )
        root.wantsLayer = true
        window.contentView = root
        window.orderFrontRegardless()
        root.displayIfNeeded()
        let box = try #require(GlassBox.make(in: root))
        GlassPlate.setContent(box.glass, NSView())
        let host = try #require(GlassBox.host(of: box.glass))
        host.afterLanding = { _, _ in }
        place(
            box.glass,
            box.tint,
            width: 63,
            animated: false,
            behind: behind
        )
        box.glass.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return Rig(
            window: window,
            glass: box.glass,
            tint: box.tint,
            host: host
        )
    }

    private func place(
        _ glass: NSView,
        _ tint: GlassBackdrop,
        width: CGFloat,
        animated: Bool,
        behind: Bool = false
    ) {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        BarMotion.runLayout {
            GlassBox.place(
                glass,
                tint: tint,
                at: CGRect(x: 10, y: 10, width: width, height: 30),
                cornerRadius: 8,
                fill: GlassFill(hex: "#202020B3"),
                edge: .top,
                visible: true,
                animated: animated,
                behind: behind
            )
        }
    }

    /// A view whose layer reads as anchored at its centre whatever
    /// AppKit writes to it: a box-sized layer off the measured shape.
    private final class CentredView: NSView {
        final class Layer: CALayer {
            override var anchorPoint: CGPoint {
                get { CGPoint(x: 0.5, y: 0.5) }
                set {}
            }
        }
        override func makeBackingLayer() -> CALayer { Layer() }
    }

    private func layers(under root: CALayer) -> [CALayer] {
        [root] + (root.sublayers ?? []).flatMap { layers(under: $0) }
    }

    /// Every layer of the pair at the host's size follows — the
    /// glass's private ones, its tint inside it or behind it, and
    /// its content — on the host's own clock, at a fractional
    /// width Auto Layout rounds the glass off (#2388).
    @Test(
        "A growing box writes its glass at once and follows the host",
        arguments: [false, true]
    )
    func glideFollowsTheHost(behind: Bool) throws {
        guard let rig = try rig(behind: behind) else { return }
        defer { rig.window.close() }
        let content = try #require(GlassPlate.contentChain(rig.glass).last)
        // A plain box-sized view ahead of the glass: the follow
        // finds the glass by kind, never by order.
        let plain = NSView(frame: rig.host.bounds)
        plain.wantsLayer = true
        rig.host.addSubview(plain, positioned: .below, relativeTo: nil)
        place(
            rig.glass,
            rig.tint,
            width: 140.3,
            animated: true,
            behind: behind
        )
        #expect(GlassPlate.fills(rig.glass.frame, rig.host.bounds))
        #expect((rig.tint.superview === rig.host) == behind)
        let hostLayer = try #require(rig.host.layer)
        let host = try #require(
            hostLayer.animation(forKey: "bounds") as? CABasicAnimation
        )
        let from = try #require((host.fromValue as? NSValue)?.rectValue)
        let size = rig.host.bounds.size
        let boxSized = rig.host.subviews.compactMap(\.layer)
            .flatMap(layers(under:))
            .filter {
                abs($0.bounds.width - size.width) <= 0.5
                    && abs($0.bounds.height - size.height) <= 0.5
            }
        let follows = boxSized.map {
            $0.animation(forKey: BarMotion.followKey) as? CABasicAnimation
        }
        #expect(!boxSized.isEmpty)
        #expect(follows.allSatisfy { $0 != nil }, "\(boxSized)")
        #expect(
            zip(boxSized, follows).contains {
                !($0.0.delegate is NSView) && $0.1 != nil
                    && isInTree($0.0, of: rig.glass.layer)
            }
        )
        for view in [rig.tint, content] {
            #expect(
                view.layer?.animation(forKey: BarMotion.followKey) != nil,
                "\(view)"
            )
        }
        for follow in follows.compactMap({ $0 }) {
            #expect(follow.duration == host.duration)
            #expect(follow.beginTime == host.beginTime)
            #expect(curve(follow.timingFunction) == curve(host.timingFunction))
            #expect((follow.fromValue as? NSValue)?.rectValue == from)
        }
    }

    /// A timing function's two control points; `==` on the
    /// function itself does not compare curves.
    private func curve(_ function: CAMediaTimingFunction?) -> [Float] {
        guard let function else { return [] }
        var points: [Float] = []
        for index in 1...2 {
            var point: [Float] = [0, 0]
            function.getControlPoint(at: index, values: &point)
            points += point
        }
        return points
    }

    /// A rewrite of the glass's frame it already has leaves its
    /// follow in place.
    @Test("An equal frame write keeps the follow")
    func equalWriteKeepsTheFollow() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        place(rig.glass, rig.tint, width: 140.3, animated: true)
        GlassPlate.update(rig.glass, frame: rig.glass.frame, cornerRadius: 8)
        let glassLayer = try #require(rig.glass.layer)
        #expect(glassLayer.animation(forKey: BarMotion.followKey) != nil)
    }

    private func isInTree(_ layer: CALayer, of root: CALayer?) -> Bool {
        var node: CALayer? = layer
        while let current = node {
            if current === root { return true }
            node = current.superlayer
        }
        return false
    }

    /// A box whose layers are not the measured shape — here a
    /// box-sized layer anchored at its centre — takes no follow,
    /// and its landing settle survives. The settle is scheduled on
    /// every glide, so this pins that it stays, not that the
    /// fallback triggered it; the shape check's other clauses are
    /// `GlassBoxFollowShapeTests`'.
    @Test("A glass off the measured shape takes no follow and settles")
    func offShapeFallsBackToTheSettle() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        let odd = CentredView(frame: rig.host.bounds)
        odd.wantsLayer = true
        rig.host.addSubview(odd, positioned: .below, relativeTo: rig.glass)
        var landings = 0
        rig.host.afterLanding = { _, _ in landings += 1 }
        place(rig.glass, rig.tint, width: 140, animated: true)
        #expect(rig.host.layer?.animation(forKey: "bounds") != nil)
        #expect(GlassPlate.fills(rig.glass.frame, rig.host.bounds))
        let glassLayer = try #require(rig.glass.layer)
        let followed = (layers(under: glassLayer) + [odd.layer!])
            .filter { $0.animation(forKey: BarMotion.followKey) != nil }
        #expect(followed.isEmpty)
        #expect(landings == 1)
    }

    /// A host that lands rather than glides carries no bounds
    /// animation, so nothing follows.
    @Test("A box that lands takes no follow")
    func landingTakesNoFollow() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        place(rig.glass, rig.tint, width: 140, animated: false)
        #expect(GlassPlate.fills(rig.glass.frame, rig.host.bounds))
        let glassLayer = try #require(rig.glass.layer)
        #expect(
            layers(under: glassLayer).allSatisfy {
                $0.animation(forKey: BarMotion.followKey) == nil
            }
        )
    }
}
