import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_floating` and a float `resize` on a window that renders
/// somewhere it is not a member (#2972, #3163): the stop is the
/// render Space's, and neither window
/// is re-filed. Space 1 shows no strip; Space 2, shown, has the Space
/// Bar's along the top.
@Suite("Move floating on a traveler", .serialized)
@MainActor
struct FloatNudgeRenderSpaceTests {
    private let one = WindowID(1)
    private let home = SpaceID("1")
    private let shown = SpaceID("2")
    private let frame = CGRect(x: 10, y: 200, width: 300, height: 200)

    private func makeCore() -> KiwiCore? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-nudge-render-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: one,
                    pid: 900_001,
                    appName: "App",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        core.state.apply(.windowFocused(one))
        core.resolveSpaceDisplays(mainID: display.id)
        var settings = core.tiler.settings
        settings.spaceBarStyle.visibility = .always
        settings.spaceBarStyle.reserve = true
        settings.barEdge = .top
        settings.kiwishelf.thickness = 40
        settings.borderStyle.enabled = true
        settings.borderStyle.width = 4
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        return core
    }

    private func arrive(_ core: KiwiCore) throws -> CGRect {
        core.state.workspaces.ensureSpace(shown)
        core.state.workspaces.setMode(shown, .bsp)
        let display = try #require(core.state.workspaces.allDisplays.first)
        core.resolveSpaceDisplays(mainID: display.id)
        core.state.workspaces.activate(shown)
        core.updateBars()
        #expect(core.focusedWindowID == one)
        #expect(core.floatPlacementSpace(of: one) == shown)
        let region = try #require(core.floatBounds(on: shown))
        #expect(region != core.floatBounds(of: one))
        #expect(core.floatRingInset > 0)
        return region
    }

    private func stopsAtTheShownBar(_ core: KiwiCore) throws {
        let region = try arrive(core)
        var cues: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { cues.append($0) }
        let response = core.execute(
            "move_floating",
            args: [.string("y"), .number(-5000)]
        )
        #expect(response.isSuccess)
        let landed = core.tiler.recentInstantTarget(one)
        #expect(landed?.minY == region.minY + core.floatRingInset)
        #expect(cues == [.moveAtBoundary(one, direction: .up)])
        #expect(core.state.workspaces.space(of: one) == home)
    }

    /// One point at a time into the bar: the clamp only pushes past
    /// its tolerance, and that push may not send the window back.
    @Test(
        "small steps into a bar never move backward",
        .enabled(if: NSScreen.main != nil)
    )
    func smallSteps() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(makeCore())
        core.execute("make_sticky")
        let region = try arrive(core)
        var y = region.minY + core.floatRingInset
        var cues: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { cues.append($0) }
        for _ in 0..<8 {
            core.state.apply(
                .windowResized(
                    one,
                    CGRect(x: 10, y: y, width: 300, height: 200)
                )
            )
            core.tiler.clearInstantTarget(one)
            core.execute(
                "move_floating",
                args: [.string("y"), .number(-1)]
            )
            let landed = core.tiler.recentInstantTarget(one)?.minY ?? y
            #expect(landed <= y)
            y = landed
        }
        #expect(cues.contains(.moveAtBoundary(one, direction: .up)))
    }

    @Test(
        "a sticky traveler stops at the bar of the Space it renders on",
        .enabled(if: NSScreen.main != nil)
    )
    func traveler() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(makeCore())
        core.execute("make_sticky")
        try stopsAtTheShownBar(core)
    }

    @Test(
        "an out pocket window stops there too, still out",
        .enabled(if: NSScreen.main != nil)
    )
    func pocketWindow() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(makeCore())
        core.execute("toggle_pocket_window")
        try stopsAtTheShownBar(core)
        #expect(core.state.pocketPhase(of: one) == .out)
    }

    /// The grow judges the render Space too (#3163): a traveler grown
    /// upward stops at the shown Space's top bar, not at its home's
    /// bare screen edge.
    @Test(
        "a sticky traveler grows to the bar of the Space it renders on",
        .enabled(if: NSScreen.main != nil)
    )
    func travelerGrow() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(makeCore())
        core.execute("make_sticky")
        let region = try arrive(core)
        core.tiler.settings.animations.onWindowResize = false
        core.execute("resize", args: [.string("y"), .number(5000)])
        let grown = try #require(core.tiler.recentInstantTarget(one))
        #expect(grown.minY == region.minY + core.floatRingInset)
        #expect(core.state.workspaces.space(of: one) == home)
    }
}
