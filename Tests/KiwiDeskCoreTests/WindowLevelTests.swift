import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The window-level fast path that pins floating windows above the
/// tiled plane (#418). The SkyLight call itself is manual-test
/// territory (foreign-process window server IPC); these pin the
/// level choice and the symbol-gated availability contract.
@Suite("Window level fast path")
struct WindowLevelTests {
    @Test("Floating sits above the tiled (normal) plane")
    func floatingAboveNormal() {
        #expect(WindowLevel.floating > WindowLevel.normal)
    }

    @Test("Levels match the CoreGraphics floating/normal keys")
    func levelsMatchCGKeys() {
        #expect(
            WindowLevel.floating
                == CGWindowLevelForKey(.floatingWindow)
        )
        #expect(
            WindowLevel.normal
                == CGWindowLevelForKey(.normalWindow)
        )
    }

    @Test("Availability tracks the private symbol resolution")
    func availabilityTracksSymbol() {
        #expect(
            WindowLevel.isAvailable
                == (SkyLight.setWindowLevel != nil)
        )
    }
}
