import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The empty-switch yield stands down only for a float the
/// WindowServer draws (#2850): BetterDisplay's 1×1 helper is no
/// focus recipient, so it must not keep the stashed window key
/// (#463). Bounds come through the watch's `readWindowBounds`
/// seam, the one the #2840 float raise reads.
@Suite("Empty-switch yield skips undrawn floats (#2850)", .serialized)
@MainActor
struct EmptySwitchYieldVisibilityTests {
    /// Window 1 (pid 5) is the focus; sticky floats 50 and 60
    /// travel to every Space; `undrawn` names the floats the
    /// WindowServer reads at 1×1, every other id at full size.
    private func makeCore(undrawn: Set<UInt32>) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-yield-\(UUID().uuidString)"
                )
        )
        for raw: UInt32 in [50, 60] {
            var float = ManagedWindow(
                id: WindowID(raw),
                pid: 6,
                appName: "Helper",
                stickyScope: .global
            )
            float.isFloating = true
            core.state.apply(.windowCreated(float))
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 5, appName: "App")
            )
        )
        core.state.apply(.windowFocused(WindowID(1)))
        core.windowServer.readWindowBounds = { id in
            undrawn.contains(id.raw)
                ? CGRect(x: 9, y: 41, width: 1, height: 1)
                : CGRect(x: 100, y: 100, width: 400, height: 300)
        }
        return core
    }

    @Test("Undrawn floats alone leave the yield standing")
    func undrawnFloatsYield() {
        let core = makeCore(undrawn: [50, 60])
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        core.execute("focus_space", args: [.string("2")])
        #expect(yields == 1)
    }

    @Test("One drawn float beside an undrawn one stands it down")
    func drawnFloatSkipsYield() {
        let core = makeCore(undrawn: [50])
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        core.execute("focus_space", args: [.string("2")])
        #expect(yields == 0)
    }
}
