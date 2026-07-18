import AppKit
import Testing

@testable import KiwiDeskCore

/// `BorderManager` draw-order is global (#367): flipping it must
/// retire every live ring so each rebuilds on the backend that
/// matches the new order (front → SkyLight above, behind → AppKit
/// below). An unchanged order is a no-op.
@Suite("Border draw order", .serialized)
@MainActor
struct BorderDrawOrderTests {
    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 200, height: 120),
            colorHex: "#0A84FF",
            width: 2,
            cornerStyle: .rounded
        )
    }

    @Test("A real order flip retires every live ring")
    func flipRetiresRings() {
        let manager = BorderManager()
        manager.sync([spec(41)])
        #expect(manager.borderedWindows == [WindowID(41)])
        // behind (default) → front: overlays retired, rebuilt next sync.
        manager.setDrawOrder(.front)
        #expect(manager.borderedWindows.isEmpty)
        manager.sync([spec(41)])
        #expect(manager.borderedWindows == [WindowID(41)])
    }

    @Test("Setting the same order keeps rings intact")
    func sameOrderIsNoOp() {
        let manager = BorderManager()
        manager.sync([spec(41)])
        // Default is behind; setting behind again must not retire.
        manager.setDrawOrder(.behind)
        #expect(manager.borderedWindows == [WindowID(41)])
    }
}
