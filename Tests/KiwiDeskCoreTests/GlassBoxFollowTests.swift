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

    private func rig() throws -> Rig? {
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
        place(box.glass, box.tint, width: 63, animated: false)
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
        animated: Bool
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
                animated: animated
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

    @Test("A growing box writes its glass at once and follows the host")
    func glideFollowsTheHost() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        // A fractional width, which Auto Layout rounds the glass off.
        place(rig.glass, rig.tint, width: 140.3, animated: true)
        #expect(GlassPlate.fills(rig.glass.frame, rig.host.bounds))
        let hostLayer = try #require(rig.host.layer)
        let host = try #require(
            hostLayer.animation(forKey: "bounds") as? CABasicAnimation
        )
        let glassLayer = try #require(rig.glass.layer)
        let follows = layers(under: glassLayer).compactMap {
            $0.animation(forKey: BarMotion.followKey) as? CABasicAnimation
        }
        #expect(!follows.isEmpty)
        for follow in follows {
            #expect(follow.duration == host.duration)
            #expect(follow.beginTime == host.beginTime)
            #expect(follow.timingFunction == host.timingFunction)
            #expect(
                (follow.fromValue as? NSValue)?.rectValue
                    == (host.fromValue as? NSValue)?.rectValue
            )
        }
    }

    /// A box whose layers are not the measured shape — here a
    /// box-sized layer anchored at its centre — takes no follow,
    /// and its landing settle is still scheduled.
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
