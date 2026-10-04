import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The live half of #1956's panel move: skipping AppKit's
/// `setFrame` is only safe while `SkyLight.moveWindow` lands, at a
/// top-left global origin. Real panels, parked off every screen,
/// the run loop pumped for WindowServer to apply them. AppKit's
/// cached frame is not read here: the moved event that updates it
/// needs an `NSApp` event loop a test does not run, and no
/// decision reads that cache (borders.md).
@Suite("Border ring panel moves, live", .serialized)
@MainActor
struct BorderPanelMoveLiveTests {
    private let size = CGSize(width: 60, height: 40)
    private let start = CGPoint(x: -9_000, y: -9_000)
    private let moved = CGPoint(x: -8_800, y: -8_960)

    @Test("A SkyLight move lands where the ring was placed")
    func moveLandsAtTopLeft() throws {
        let target = makeTarget()
        defer { target.orderOut(nil) }
        let ring = AppKitBorderOverlay(
            order: .below,
            movePanel: SkyLight.moveWindow
        )
        defer { ring.hide() }
        render(ring, at: start)
        ring.order(relativeTo: CGWindowID(target.windowNumber))
        let number = try #require(ring.panelNumber)
        _ = pump { bounds(of: number) != nil }
        // A pass ends, so AppKit's own placement has been sent.
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        render(ring, at: moved)
        #expect(ring.skyLightMoves == 1)
        #expect(ring.frameSets == 1)
        let expected = exactFrame(at: moved)
        let topLeft = GeometryUtils.flip(
            expected,
            primaryHeight: GeometryUtils.primaryHeight
        )
        #expect(pump { bounds(of: number) == topLeft })
    }

    @Test("The manager's seam reaches the ring's panel")
    func managerSeamReachesThePanel() {
        let border = BorderManager()
        defer { border.clear() }
        border.restack = { _, _, _ in false }
        var moves = 0
        border.movePanel = { _, _ in
            moves += 1
            return true
        }
        border.watchOverride = { _ in true }
        let spec: (CGFloat) -> BorderManager.Spec = { x in
            BorderManager.Spec(
                window: WindowID(9),
                frame: CGRect(x: x, y: -9_000, width: 60, height: 40),
                colorHex: "#FF0000",
                width: 4,
                cornerStyle: .rounded
            )
        }
        border.sync([spec(-9_000)], alive: nil, reassertOrder: false)
        #expect(moves == 0)
        // A pass ends, so AppKit's own placement has been sent.
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        border.sync([spec(-8_900)], alive: nil, reassertOrder: false)
        #expect(moves == 1)
    }

    private func render(_ ring: AppKitBorderOverlay, at origin: CGPoint) {
        ring.update(
            geometry: BorderGeometry.compute(
                windowFrame: CGRect(origin: origin, size: size),
                width: 4,
                cornerStyle: .rounded,
                order: .below,
                systemRadius: 10
            ),
            colorHex: "#FF0000",
            screen: nil,
            room: nil
        )
    }

    private func exactFrame(at origin: CGPoint) -> CGRect {
        let exact = AppKitBorderOverlay(
            order: .below,
            movePanel: { _, _ in false }
        )
        render(exact, at: origin)
        return exact.panelFrame ?? .zero
    }

    private func bounds(of number: Int) -> CGRect? {
        let info =
            CGWindowListCopyWindowInfo(
                .optionIncludingWindow,
                CGWindowID(number)
            ) as? [[String: Any]]
        guard
            let row = info?.first?[kCGWindowBounds as String]
                as? NSDictionary
        else { return nil }
        return CGRect(dictionaryRepresentation: row as CFDictionary)
    }

    /// Pumps the run loop until `done`, within a generous bound.
    private func pump(until done: () -> Bool) -> Bool {
        for _ in 0..<100 {
            if done() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return done()
    }

    private func makeTarget() -> NSPanel {
        let target = NSPanel(
            contentRect: CGRect(origin: start, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        target.isReleasedWhenClosed = false
        target.orderFrontRegardless()
        return target
    }
}
