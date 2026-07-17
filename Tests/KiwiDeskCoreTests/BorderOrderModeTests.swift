import AppKit
import Testing

@testable import KiwiDeskCore

/// The facade owns the ring's order mode and rebuilds geometry for
/// it — on every render and after a fallback swap (#357). An `above`
/// SkyLight geometry (visible hairline lap) cannot be reused by the
/// `below` AppKit panel (masked overlap), so the mode must drive the
/// geometry, not a value precomputed upstream.
@Suite("Border order mode")
@MainActor
struct BorderOrderModeTests {
    private let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

    @Test("An above backend receives above-order geometry")
    func aboveBackendGetsAboveGeometry() {
        let backend = GeometryCapturingBackend(orderMode: .above)
        let overlay = BorderOverlay(window: 7, backend: backend)
        overlay.update(
            frame: frame,
            width: 6,
            cornerStyle: .rounded,
            colorHex: "#0A84FF",
            screen: nil
        )
        let expected = BorderGeometry.compute(
            windowFrame: frame,
            width: 6,
            cornerStyle: .rounded,
            order: .above
        )
        #expect(backend.lastGeometry == expected)
        // The on-window capped lap (1), not the hidden 5.
        #expect(backend.lastGeometry?.lineWidth == 7.0)
    }

    @Test("A below backend receives below-order geometry")
    func belowBackendGetsBelowGeometry() {
        let backend = GeometryCapturingBackend(orderMode: .below)
        let overlay = BorderOverlay(window: 7, backend: backend)
        overlay.update(
            frame: frame,
            width: 6,
            cornerStyle: .rounded,
            colorHex: "#0A84FF",
            screen: nil
        )
        #expect(
            backend.lastGeometry?.lineWidth
                == 6 + BorderGeometry.roundedHiddenOverlap
        )
    }

    /// The #357 fallback contract: when an `above` primary fails and
    /// the facade retires it, the replay through the `below` panel
    /// must be recomputed for below-order — reusing the above
    /// geometry would draw the hairline overlap as the whole ring.
    @Test("Fallback rebuilds geometry for the below panel")
    func fallbackRebuildsForBelow() {
        let primary = GeometryCapturingBackend(orderMode: .above)
        primary.updateSucceeds = false
        let fallback = GeometryCapturingBackend(orderMode: .below)
        let overlay = BorderOverlay(
            window: 7,
            backend: primary,
            fallback: fallback
        )
        overlay.update(
            frame: frame,
            width: 6,
            cornerStyle: .rounded,
            colorHex: "#0A84FF",
            screen: nil
        )
        #expect(
            fallback.lastGeometry?.lineWidth
                == 6 + BorderGeometry.roundedHiddenOverlap
        )
    }
}

@MainActor
private final class GeometryCapturingBackend: BorderOverlayBackend {
    let orderMode: BorderGeometry.Order
    var updateSucceeds = true
    var lastGeometry: BorderGeometry?

    init(orderMode: BorderGeometry.Order) {
        self.orderMode = orderMode
    }

    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) -> Bool {
        lastGeometry = geometry
        return updateSucceeds
    }

    func order(relativeTo windowNumber: CGWindowID) -> Bool { true }
    func hide() -> Bool { true }
}
