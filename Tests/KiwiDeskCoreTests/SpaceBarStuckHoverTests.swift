import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space Bar chip's hover follows the pointer across renders
/// (#1665): a click re-lays the bar, the chip moves out from under
/// the resting pointer, AppKit sends no exit, and the hover fill
/// stayed on the chip until the pointer crossed it again. Rendered
/// through `SpaceBarManager.sync`, the production arm.
@Suite("Space Bar stuck hover (#1665)", .serialized)
@MainActor
struct SpaceBarStuckHoverTests {
    private func bars(active: String) -> [SpaceBarManager.Bar] {
        var style = SpaceBarLook()
        style.liquidGlass = false
        let items = ["1", "2"].map {
            SpaceBarOverlay.Item(
                space: SpaceID($0),
                spaceGlyph: .text($0, tinted: true),
                apps: [],
                active: $0 == active,
                overflow: 0,
                focusInOverflow: false
            )
        }
        return [
            SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: items,
                strip: barTitleStrip,
                style: style,
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ]
    }

    private func chip(
        _ space: String,
        in manager: SpaceBarManager
    ) throws -> SpaceBarItemView {
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        return try #require(
            overlay.itemViews.first { $0.space == SpaceID(space) }
        )
    }

    /// Shows the bar and hosts its section in a window, the part
    /// `ShelfOverlay` plays in production.
    private func hosted() throws -> (SpaceBarManager, NSWindow) {
        let manager = SpaceBarManager()
        manager.sync(bars(active: "1"))
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let window = NSWindow(
            contentRect: barTitleStrip,
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        let content = NSView(frame: barTitleStrip)
        window.contentView = content
        content.addSubview(overlay.root)
        overlay.root.frame = content.bounds
        manager.sync(bars(active: "1"))
        return (manager, window)
    }

    /// The chip's centre in its window's points.
    private func centre(of view: NSView) -> CGPoint {
        view.convert(
            CGPoint(x: view.bounds.midX, y: view.bounds.midY),
            to: nil
        )
    }

    @Test("a render re-reads the hover from where the pointer rests")
    func renderFollowsThePointer() throws {
        LiquidGlassGate.override = { false }
        defer { BarHoverHit.pointerOverride = nil }
        let (manager, window) = try hosted()
        let two = try chip("2", in: manager)
        #expect(two.window === window)
        let over = centre(of: two)
        BarHoverHit.pointerOverride = { _ in over }
        manager.sync(bars(active: "1"))
        // The positive arm: the render finds the chip under the
        // pointer, so the negative one below is not vacuous.
        #expect(two.isHovered)
    }

    @Test("a chip the pointer left without an exit loses its hover")
    func leftWithoutAnExit() throws {
        LiquidGlassGate.override = { false }
        defer { BarHoverHit.pointerOverride = nil }
        let (manager, window) = try hosted()
        let two = try chip("2", in: manager)
        #expect(two.window === window)
        let moved = try #require(
            NSEvent.mouseEvent(
                with: .mouseMoved,
                location: centre(of: two),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            )
        )
        two.mouseMoved(with: moved)
        #expect(two.isHovered)
        // The click switches to 2 and the bar re-lays; the pointer
        // ends up off every chip, and no exit event arrives.
        BarHoverHit.pointerOverride = { _ in CGPoint(x: -500, y: -500) }
        manager.sync(bars(active: "2"))
        manager.sync(bars(active: "1"))
        #expect(!two.isHovered)
    }
}
