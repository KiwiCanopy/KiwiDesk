import AppKit
import Testing

@testable import KiwiDeskCore

/// A bar item hovers only where it owns the pointer (#1517): the
/// overflow count drawn over its faded end takes the pointer
/// there, though the item's tracking area still covers it.
@Suite("Bar hover hit")
@MainActor
struct BarHoverHitTests {
    private func move(to point: CGPoint, in window: NSWindow) throws -> NSEvent
    {
        try #require(
            NSEvent.mouseEvent(
                with: .mouseMoved,
                location: point,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            )
        )
    }

    @Test("An item under the count does not own the pointer")
    func countTakesThePointer() throws {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 30),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
        window.contentView = content
        let item = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
        let count = NSView(frame: CGRect(x: 170, y: 0, width: 30, height: 30))
        let glyph = NSView(frame: CGRect(x: 10, y: 5, width: 20, height: 20))
        content.addSubview(item)
        item.addSubview(glyph)
        content.addSubview(count)
        #expect(
            BarHoverHit.owns(
                item,
                try move(to: CGPoint(x: 100, y: 15), in: window)
            )
        )
        // Inside the item's own content still counts as the item.
        #expect(
            BarHoverHit.owns(
                item,
                try move(to: CGPoint(x: 20, y: 15), in: window)
            )
        )
        #expect(
            !BarHoverHit.owns(
                item,
                try move(to: CGPoint(x: 185, y: 15), in: window)
            )
        )
    }
}
