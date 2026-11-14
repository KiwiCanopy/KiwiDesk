import AppKit
import Testing

@testable import KiwiDeskCore

/// `BarMotion.followTargets`' shape check, clause by clause: each
/// box off the measured shape answers nil, so the follow adds
/// nothing and the landing settle repairs the frame (#2878 ruling
/// amendment, 2026-11-14). Main-actor spend: one small window and
/// one glass layout per test.
@Suite("Glass box follow shape", .serialized)
@MainActor
struct GlassBoxFollowShapeTests {
    @MainActor
    private struct Rig {
        let window: NSWindow
        let glass: NSView
        let host: GlassBoxHost

        var pair: [NSView] {
            host.subviews.filter { !($0 is GlassBoxRider) }
        }

        func targets(
            host layer: CALayer? = nil,
            glass view: NSView? = nil,
            pair extra: [NSView] = []
        ) throws -> [CALayer]? {
            BarMotion.followTargets(
                host: try #require(layer ?? host.layer),
                glass: view ?? glass,
                pair: pair + extra
            )
        }
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
        let box = try #require(GlassBox.make(in: root))
        GlassPlate.setContent(box.glass, NSView())
        let host = try #require(GlassBox.host(of: box.glass))
        host.afterLanding = { _, _ in }
        GlassBox.place(
            box.glass,
            tint: box.tint,
            at: CGRect(x: 10, y: 10, width: 140, height: 30),
            cornerRadius: 8,
            fill: GlassFill(hex: "#202020B3"),
            edge: .top,
            visible: true,
            animated: false
        )
        BarMotion.layoutStill(box.glass)
        window.displayIfNeeded()
        return Rig(window: window, glass: box.glass, host: host)
    }

    /// A box-sized layer in the glass's tree, off the shape by
    /// `anchor` or `origin` alone.
    private func stray(
        in rig: Rig,
        anchor: CGPoint = .zero,
        origin: CGPoint = .zero
    ) throws {
        let layer = CALayer()
        layer.anchorPoint = anchor
        layer.bounds = CGRect(origin: origin, size: rig.host.bounds.size)
        try #require(rig.glass.layer).addSublayer(layer)
    }

    @Test("The measured shape passes")
    func measuredShapePasses() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        #expect(try rig.targets()?.isEmpty == false)
    }

    @Test("A glass that does not fill its host takes no follow")
    func unfilledGlassRefuses() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        let wider = CALayer()
        wider.bounds = CGRect(x: 0, y: 0, width: 200, height: 30)
        #expect(try rig.targets(host: wider) == nil)
    }

    @Test("A tree with no private layer takes no follow")
    func viewBackedOnlyRefuses() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        let plain = NSView(frame: rig.host.bounds)
        plain.wantsLayer = true
        rig.host.addSubview(plain)
        #expect(try rig.targets(glass: plain) == nil)
    }

    @Test("A pair view off the host's size takes no follow")
    func unmatchedPairViewRefuses() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        let short = NSView(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        short.wantsLayer = true
        rig.host.addSubview(short)
        #expect(try rig.targets() == nil)
    }

    @Test("A box-sized layer off its origin takes no follow")
    func offsetLayerRefuses() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        try stray(in: rig, origin: CGPoint(x: 3, y: 0))
        #expect(try rig.targets() == nil)
    }

    @Test("A box-sized layer anchored off its origin takes no follow")
    func centredLayerRefuses() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        try stray(in: rig, anchor: CGPoint(x: 0.5, y: 0.5))
        #expect(try rig.targets() == nil)
    }
}
