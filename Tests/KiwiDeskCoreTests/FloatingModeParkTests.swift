import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// #500 end to end: parking a floating-mode space captures its
/// members' frames — flag or no flag — so activating the space
/// restores them instead of leaving them in the stash corner.
@Suite("Floating-mode space park (#500)", .serialized)
@MainActor
struct FloatingModeParkTests {
    @Test("Parking a floating-mode space captures every member")
    func parkCapturesMembers() {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-floatpark-\(UUID().uuidString)"
                )
        )
        core.execute(
            "set_mode",
            args: [.string("2"), .string("floating")]
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "A"
                )
            )
        )
        let frame = CGRect(
            x: 300,
            y: 200,
            width: 800,
            height: 600
        )
        core.state.apply(.windowMoved(WindowID(1), frame))
        // The move parks space 2's member on the retile; the
        // NON-flagged window must capture its original like a
        // float would — no layout will ever place it back.
        core.moveWindow(
            WindowID(1),
            to: SpaceID(2),
            follow: false
        )
        #expect(
            core.tiler.stashOriginal(WindowID(1)) == frame
        )
        #expect(
            core.state.windows[WindowID(1)]?.isFloating == false
        )
    }
}
