import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's plate stands down where the screen is covered — a
/// native fullscreen Space or a presentation — and never for a
/// Maximize, which stands the bars down alone (#3061). An
/// extension of this suite, not a second one: every case holds the
/// process-global `currentSpaceIsUserOverride` (see the suite's
/// header).
extension FullscreenStandDownTests {
    /// A core with two tiled windows on the primary screen's Space,
    /// the first focused, its Space Bar always shown. Nil where the
    /// host has no screen.
    private func makeMaximizeCore(isUser: Bool) -> (KiwiCore, DisplayID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        NativeSpaces.currentSpaceIsUserOverride = { _ in isUser }
        let core = makeCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.frontStack = { [] }
        core.state.apply(.displaysChanged([display]))
        for raw in [UInt32(1), 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: pid_t(900_000 + raw),
                        appName: "App\(raw)"
                    )
                )
            )
        }
        core.resolveSpaceDisplays(mainID: display.id)
        guard let space = core.state.workspaces.space(of: WindowID(1))
        else { return nil }
        core.state.workspaces.setMode(space, .bsp)
        core.state.workspaces.focus(WindowID(1), in: space)
        core.tiler.settings.spaceBarStyle.visibility = .always
        return (core, display.id)
    }

    @Test("a Maximize stands the bars down and keeps the plate")
    func maximizeKeepsThePlate() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeMaximizeCore(isUser: true)
        )
        core.updateBars()
        #expect(!core.spaceBars.shownStrips.isEmpty)
        #expect(core.vision.standDown.isEmpty)

        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(core.showsMaximized(on: display))
        core.updateBars()
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(!core.vision.standDown.contains(display))
    }

    /// The control: a covered screen still stands the plate down,
    /// so the case above cannot pass on a plate that never does.
    @Test("a fullscreen Space stands the plate down")
    func fullscreenStandsThePlateDown() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeMaximizeCore(isUser: false)
        )
        core.updateBars()
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(core.vision.standDown.contains(display))
    }
}
