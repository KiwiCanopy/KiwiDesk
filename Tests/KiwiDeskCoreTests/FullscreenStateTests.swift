import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The native-fullscreen snapshot flag: the `.windowFullscreenChanged`
/// fold flips `ManagedWindow.isFullscreen` (ring suppression reads
/// it), and float mutations leave it alone — fullscreen is
/// detection-owned and orthogonal to floating, so `setFloating`
/// must not clear it (the reconcile recheck is the single heal
/// path; a clear here would desync the event loop's change-only
/// cache).
@Suite("Native-fullscreen state flag")
struct FullscreenStateTests {
    private func makeWindow(_ id: UInt32) -> ManagedWindow {
        ManagedWindow(id: WindowID(id), pid: 7, appName: "App")
    }

    @Test("The fold flips the flag on and off")
    func foldAppliesVerdict() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        #expect(state.windows[WindowID(1)]?.isFullscreen == false)
        state.apply(
            .windowFullscreenChanged(
                WindowID(1),
                isFullscreen: true
            )
        )
        #expect(state.windows[WindowID(1)]?.isFullscreen == true)
        state.apply(
            .windowFullscreenChanged(
                WindowID(1),
                isFullscreen: false
            )
        )
        #expect(state.windows[WindowID(1)]?.isFullscreen == false)
    }

    @Test("Float mutations leave the fullscreen flag alone")
    func floatMutationKeepsFlag() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(
            .windowFullscreenChanged(
                WindowID(1),
                isFullscreen: true
            )
        )
        // Neither a manual make_tiled nor a detection self-heal
        // may drop the fullscreen verdict (unlike the overlay
        // flag, which is coupled to floating, #300).
        state.setFloating(WindowID(1), false)
        #expect(state.windows[WindowID(1)]?.isFullscreen == true)
        state.apply(
            .windowFloatChanged(WindowID(1), isFloating: false)
        )
        #expect(state.windows[WindowID(1)]?.isFullscreen == true)
    }
}
