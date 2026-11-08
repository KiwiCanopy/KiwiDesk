import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A screen move (#3117) onto a screen showing a native full-screen
/// Space refuses: the window would be filed under a Space that
/// screen cannot show. An extension of this suite, not a second
/// one: the case holds the process-global
/// `currentSpaceIsUserOverride` (see the suite's header).
extension FullscreenStandDownTests {
    @Test("a screen move refuses a screen on a full-screen Space")
    func screenMoveRefusesFullScreen() {
        let a = DisplayID(9_301)
        let b = DisplayID(9_302)
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-screen-move-fs-\(UUID().uuidString)"
                )
        )
        let screens: [ScreenHop.Screen] = [
            (a, CGRect(x: 0, y: 0, width: 1000, height: 800)),
            (b, CGRect(x: 1000, y: 0, width: 1000, height: 800)),
        ]
        core.tiler.displayFrames = { screens }
        for (index, screen) in screens.enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(id: screen.id, name: "S\(index)", frame: screen.frame)
            )
            let space = SpaceID("\(index + 1)")
            core.state.workspaces.assign(space, to: screen.id)
            core.state.workspaces.activate(space)
        }
        core.state.workspaces.activate(SpaceID("1"))
        let window = WindowID(1)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: window,
                    pid: 900_301,
                    appName: "App1",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
        core.state.apply(.windowFocused(window))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }

        NativeSpaces.currentSpaceIsUserOverride = { $0 != b }
        let refused = core.execute("move_to_display_last")
        #expect(!refused.isSuccess)
        #expect(core.state.workspaces.space(of: window) == "1")

        // The control: the same move onto a user Desktop lands.
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        #expect(core.execute("move_to_display_last").isSuccess)
        #expect(core.state.workspaces.space(of: window) == "2")
    }
}
