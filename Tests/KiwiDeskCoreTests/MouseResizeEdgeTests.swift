import CoreGraphics
import Testing

@testable import KiwiDeskCore

@Suite("Mouse resize edge detection")
struct MouseResizeEdgeTests {
    private func grown(
        _ rect: CGRect,
        dw: CGFloat = 0,
        dh: CGFloat = 0
    ) -> CGRect {
        CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width + dw,
            height: rect.height + dh
        )
    }

    @Test("Outer-edge resizes are dropped, inner ones kept")
    func innerEdgesOnly() {
        // Master (left) and one stack window (right).
        let master = CGRect(
            x: 20,
            y: 45,
            width: 580,
            height: 700
        )
        let stack = CGRect(
            x: 620,
            y: 45,
            width: 360,
            height: 700
        )
        // Master pulled narrower from its LEFT (outer) edge:
        // width change reverted, nothing to trade there.
        let outer = CGRect(
            x: 120,
            y: 45,
            width: 480,
            height: 700
        )
        #expect(
            MouseResize.keepingInnerEdgeChanges(
                slot: master,
                frame: outer,
                neighbors: [stack],
                shrinkTrades: { _ in false }
            ).width == master.width
        )
        // Master pulled wider on its RIGHT (inner) edge:
        // the stack is there to give way — change kept.
        let inner = grown(master, dw: 100)
        #expect(
            MouseResize.keepingInnerEdgeChanges(
                slot: master,
                frame: inner,
                neighbors: [stack],
                shrinkTrades: { _ in false }
            ).width == master.width + 100
        )
        // Stack pulled narrower from its RIGHT (outer) edge.
        let stackOuter = CGRect(
            x: 620,
            y: 45,
            width: 260,
            height: 700
        )
        #expect(
            MouseResize.keepingInnerEdgeChanges(
                slot: stack,
                frame: stackOuter,
                neighbors: [master],
                shrinkTrades: { _ in false }
            ).width == stack.width
        )
        // Height changes with no vertical neighbor revert.
        #expect(
            MouseResize.keepingInnerEdgeChanges(
                slot: master,
                frame: grown(master, dh: 80),
                neighbors: [stack],
                shrinkTrades: { _ in false }
            ).height == master.height
        )
    }

    @Test("A shrink the zone can take stays, per axis; a grow never")
    func shrinkTradesKeepsTheShrink() {
        let slot = CGRect(x: 20, y: 45, width: 580, height: 700)
        let shrunk = CGRect(x: 20, y: 145, width: 580, height: 600)
        let trades = { (vertical: Bool) in vertical }
        #expect(
            MouseResize.keepingInnerEdgeChanges(
                slot: slot,
                frame: shrunk,
                neighbors: [],
                shrinkTrades: trades
            ).height == 600
        )
        // The width axis does not trade, whatever the height does.
        let narrowed = CGRect(x: 120, y: 45, width: 480, height: 700)
        #expect(
            MouseResize.keepingInnerEdgeChanges(
                slot: slot,
                frame: narrowed,
                neighbors: [],
                shrinkTrades: trades
            ).width == 580
        )
        // The mirror: the width trades, the height does not.
        let widthTrades = { (vertical: Bool) in !vertical }
        #expect(
            MouseResize.keepingInnerEdgeChanges(
                slot: slot,
                frame: narrowed,
                neighbors: [],
                shrinkTrades: widthTrades
            ).width == 480
        )
        #expect(
            MouseResize.keepingInnerEdgeChanges(
                slot: slot,
                frame: shrunk,
                neighbors: [],
                shrinkTrades: widthTrades
            ).height == 700
        )
        // A grow on the outer edge has nobody to take room from.
        let grew = grown(slot, dw: 80, dh: 80)
        let kept = MouseResize.keepingInnerEdgeChanges(
            slot: slot,
            frame: grew,
            neighbors: [],
            shrinkTrades: { _ in true }
        )
        expectEqual(kept.height, 700)
        expectEqual(kept.width, 580)
    }

    @Test("Near-edge band detects resize start points")
    func nearEdge() {
        let rect = CGRect(x: 100, y: 100, width: 400, height: 300)
        // On the right edge, slightly outside and inside.
        #expect(
            MouseResize.nearEdge(
                CGPoint(x: 503, y: 250),
                of: rect
            )
        )
        #expect(
            MouseResize.nearEdge(
                CGPoint(x: 494, y: 250),
                of: rect
            )
        )
        // Window center and far outside are not edges.
        #expect(
            !MouseResize.nearEdge(
                CGPoint(x: 300, y: 250),
                of: rect
            )
        )
        #expect(
            !MouseResize.nearEdge(
                CGPoint(x: 600, y: 250),
                of: rect
            )
        )
    }
}
