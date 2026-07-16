import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let display = CGRect(
    x: 0,
    y: 0,
    width: 1920,
    height: 1080
)

/// #309: raised-layer windows that are fully transparent or
/// entirely off-screen are lifecycle keepalives, not user
/// windows — they must never be tracked. Pure signal matrix;
/// the CG reads live in `serverSnapshot`.
@Suite("Invisible helper windows (#309)")
struct InvisibleHelperTests {
    private func helper(
        layer: Int? = 3,
        alpha: Double? = 1,
        bounds: CGRect? = CGRect(
            x: 100,
            y: 100,
            width: 400,
            height: 300
        ),
        displays: [CGRect] = [display]
    ) -> Bool {
        FloatDetection.isInvisibleHelper(
            layer: layer,
            alpha: alpha,
            bounds: bounds,
            displays: displays
        )
    }

    @Test("the CodexBar keepalive shape is a helper")
    func codexBarKeepalive() {
        // 20×20, off-screen at (-5000, 6116), alpha 0, layer 3.
        #expect(
            helper(
                layer: 3,
                alpha: 0,
                bounds: CGRect(
                    x: -5000,
                    y: 6116,
                    width: 20,
                    height: 20
                )
            )
        )
    }

    @Test("alpha 0 on a raised layer is a helper on its own")
    func transparentRaised() {
        #expect(helper(alpha: 0))
    }

    @Test("fully off-screen raised layer is a helper")
    func offscreenRaised() {
        #expect(
            helper(
                bounds: CGRect(
                    x: -5000,
                    y: 6116,
                    width: 20,
                    height: 20
                )
            )
        )
    }

    @Test("normal-layer windows are never helpers")
    func normalLayerExempt() {
        // KiwiDesk parks inactive-space windows off-screen at
        // the peek corner — layer 0 must stay managed.
        #expect(!helper(layer: 0, alpha: 0))
        #expect(
            !helper(
                layer: 0,
                bounds: CGRect(
                    x: -9000,
                    y: 0,
                    width: 400,
                    height: 300
                )
            )
        )
        #expect(!helper(layer: nil, alpha: 0))
    }

    @Test("visible raised-layer overlays stay tracked")
    func visibleOverlayExempt() {
        // Spotlight-style: raised layer, on screen, opaque —
        // the #300 transient-overlay class, not a helper.
        #expect(!helper())
        // Partially fading in already counts as visible.
        #expect(!helper(alpha: 0.2))
        // A raised window straddling the display edge
        // intersects it — visible.
        #expect(
            !helper(
                bounds: CGRect(
                    x: 1900,
                    y: 40,
                    width: 400,
                    height: 300
                )
            )
        )
    }

    @Test("missing signals never classify")
    func missingSignals() {
        // No alpha and no bounds (window-list race): keep
        // tracking; wrongly dropping a real window costs more
        // than tracking a helper for one beat.
        #expect(!helper(alpha: nil, bounds: nil))
        // No display list (headless race): the off-screen
        // check cannot run.
        #expect(
            !helper(
                bounds: CGRect(
                    x: -5000,
                    y: 0,
                    width: 20,
                    height: 20
                ),
                displays: []
            )
        )
    }
}
