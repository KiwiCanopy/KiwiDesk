import AppKit
import Testing

@testable import KiwiDeskCore

/// **A side bar's hover lands on the item under the pointer**
/// (#3414): `NSView.hitTest` reads its superview's coordinates, and a
/// bar panel's content root is flipped inside an unflipped frame, so
/// reading the point in the root's own coordinates mirrored y. A top
/// or bottom bar's items span the strip's whole height, so the mirror
/// landed on the same item there; along a side bar it landed on
/// another item, or on none.
@Suite("Bar hover hit on a side bar (#3414)", .serialized)
@MainActor
struct BarHoverHitSideBarTests {
    @Test("each item of a vertical stack owns the pointer on it")
    func verticalStackOwnsItsPointer() {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 40, height: 300),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        defer {
            BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
        }
        let root = AppBarOverlay.FlippedView(
            frame: CGRect(x: 0, y: 0, width: 40, height: 300)
        )
        panel.contentView = root
        let items = [0, 120, 240].map { y in
            AppBarOverlay.FlippedView(
                frame: CGRect(x: 0, y: CGFloat(y), width: 40, height: 60)
            )
        }
        items.forEach(root.addSubview)
        for item in items {
            let centre = item.convert(CGPoint(x: 20, y: 30), to: nil)
            BarHoverHit.pointerOverride = { _ in centre }
            for other in items {
                #expect(BarHoverHit.ownsPointer(other) == (other === item))
            }
        }
    }
}
