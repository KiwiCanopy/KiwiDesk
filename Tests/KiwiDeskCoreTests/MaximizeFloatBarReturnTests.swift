import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A maximized float returns to its old frame where the Space Bar
/// shows (#3157). The return is paid at the retile's tail and the
/// bar sweep runs after it: judging the state frame, still the
/// fill's echo, it fitted the fill into the float region and
/// overwrote the return. The writes are instant, so the frame last
/// sent is the applier's instant target; the app's echo is folded
/// by hand between the presses, as it lands after a pass.
@Suite("Maximized float returns under a shown bar", .serialized)
@MainActor
struct MaximizeFloatBarReturnTests {
    private static let window = WindowID(1)

    private func makeBarredCore(frame: CGRect) -> KiwiCore? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.tiler.allScreenBounds = { [screen.frame] }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 900_001,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        core.state.apply(.windowFocused(Self.window))
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.barEdge = .top
        core.tiler.settings.kiwishelf.thickness = 40
        core.tiler.settings.animations.onStateChange = false
        core.tiler.settings.animations.onWindowResize = false
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return core
    }

    /// Presses `args`, folds the fill's echo, presses again, and
    /// returns the frame last sent.
    private func roundTrip(
        _ core: KiwiCore,
        _ args: [JSONValue] = []
    ) throws -> CGRect? {
        #expect(core.execute("toggle_maximized", args: args).isSuccess)
        let fill = try #require(
            core.tiler.recentInstantTarget(Self.window),
            "the press sent no fill"
        )
        core.state.apply(.windowResized(Self.window, fill))
        core.tiler.clearInstantTarget(Self.window)
        #expect(core.execute("toggle_maximized", args: args).isSuccess)
        return core.tiler.recentInstantTarget(Self.window)
    }

    private func start(on screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.minX + 300,
            y: screen.frame.minY + 250,
            width: 600,
            height: 400
        )
    }

    @Test(
        "A full Maximize returns to the old frame, not the region",
        .enabled(if: NSScreen.main != nil)
    )
    func fullReturns() throws {
        let screen = try #require(NSScreen.screens.first)
        let start = start(on: screen)
        let core = try #require(makeBarredCore(frame: start))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        try #require(
            core.spaceBars.shownStrips.first != nil,
            "no bar painted — the clause would pass vacuously"
        )
        #expect(try roundTrip(core) == start)
    }

    @Test(
        "A Height Maximize returns to the old frame",
        .enabled(if: NSScreen.main != nil)
    )
    func heightReturns() throws {
        let screen = try #require(NSScreen.screens.first)
        let start = start(on: screen)
        let core = try #require(makeBarredCore(frame: start))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        try #require(
            core.spaceBars.shownStrips.first != nil,
            "no bar painted — the clause would pass vacuously"
        )
        #expect(try roundTrip(core, [.string("height")]) == start)
    }
}
