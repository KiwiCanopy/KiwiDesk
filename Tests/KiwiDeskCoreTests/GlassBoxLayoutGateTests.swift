import AppKit
import Testing

@testable import KiwiDeskCore

/// A box's glass is laid out at once only while its host glides to a
/// new size — carries a Core Animation bounds animation — since that
/// layout is the follow's whole cost on a growing box (#2878 ruling
/// amendment, 2026-11-14: 6.3 of 7.5 ms on device). A plain place, a
/// glide that only moves the box, and a host carrying another
/// animation leave the layout to AppKit's own pass. The shape check
/// reads the laid-out layers, so the layout precedes it and its
/// refusal cannot gate it. Main-actor spend: one small window and a
/// few glass places per test.
@Suite("Glass box layout gate", .serialized)
@MainActor
struct GlassBoxLayoutGateTests {
    /// Content that counts the layout passes reaching it.
    private final class CountingView: NSView {
        var layouts = 0
        override func layout() {
            super.layout()
            layouts += 1
        }
    }

    private struct Rig {
        let window: NSWindow
        let glass: NSView
        let tint: GlassBackdrop
        let host: GlassBoxHost
        let content: CountingView
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
        let content = CountingView()
        GlassPlate.setContent(box.glass, content)
        let host = try #require(GlassBox.host(of: box.glass))
        host.afterLanding = { _, _ in }
        let rig = Rig(
            window: window,
            glass: box.glass,
            tint: box.tint,
            host: host,
            content: content
        )
        place(rig, x: 10, width: 63, animated: false)
        box.glass.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return rig
    }

    private func place(
        _ rig: Rig,
        x: CGFloat,
        width: CGFloat,
        animated: Bool
    ) {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        BarMotion.runLayout {
            GlassBox.place(
                rig.glass,
                tint: rig.tint,
                at: CGRect(x: x, y: 10, width: width, height: 30),
                cornerRadius: 8,
                fill: GlassFill(hex: "#202020B3"),
                edge: .top,
                visible: true,
                animated: animated
            )
        }
    }

    /// Layout passes `body` forces on the content, with a layout
    /// pending beforehand so a forced one has something to run.
    private func layouts(_ rig: Rig, _ body: () -> Void) -> Int {
        rig.content.needsLayout = true
        rig.content.layouts = 0
        body()
        return rig.content.layouts
    }

    @Test("A glide to a new size lays the glass out at once")
    func resizingGlideLaysOut() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        let count = layouts(rig) {
            place(rig, x: 10, width: 140.3, animated: true)
        }
        #expect(rig.host.layer?.animation(forKey: "bounds") != nil)
        #expect(count > 0)
    }

    @Test("A plain place leaves the layout to AppKit")
    func plainPlaceDefers() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        let count = layouts(rig) {
            place(rig, x: 10, width: 140.3, animated: false)
        }
        #expect(GlassPlate.fills(rig.glass.frame, rig.host.bounds))
        #expect(count == 0)
    }

    /// A scroll moves the box at its size: the host travels by its
    /// position alone and takes no size.
    @Test("A glide that only moves the box leaves the layout to AppKit")
    func movingGlideDefers() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        let count = layouts(rig) {
            place(rig, x: 120, width: 63, animated: true)
        }
        #expect(rig.host.frame.minX == 120)
        #expect(count == 0)
    }

    @Test("A host carrying another animation leaves the layout to AppKit")
    func otherAnimationDefers() throws {
        guard let rig = try rig() else { return }
        defer { rig.window.close() }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.duration = 0.4
        try #require(rig.host.layer).add(fade, forKey: "opacity")
        let count = layouts(rig) {
            rig.host.setFrameSize(NSSize(width: 140.3, height: 30))
        }
        #expect(count == 0)
    }
}
