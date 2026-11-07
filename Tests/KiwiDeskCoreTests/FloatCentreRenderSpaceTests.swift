import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `center_floating` on a window that renders somewhere it is not a
/// member (#3007): a sticky traveler and an out pocket window take
/// the region and the bar clamp of the Space they render on, and
/// neither is re-filed. Space 1 shows no strip; Space 2, shown, has
/// the Space Bar's, so the home's region differs from the render's.
@Suite("Center floating on a traveler", .serialized)
@MainActor
struct FloatCentreRenderSpaceTests {
    private let one = WindowID(1)
    private let home = SpaceID("1")
    private let shown = SpaceID("2")

    private func makeCore(
        frame: CGRect,
        edge: AppBarEdge = .top,
        applied: @escaping @MainActor (WindowID, CGRect) -> Void
    ) -> KiwiCore? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-centre-render-\(UUID().uuidString)"
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
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.visibility = .always
        settings.spaceBarStyle.reserve = true
        settings.barEdge = edge
        settings.kiwishelf.thickness = 40
        settings.borderStyle.enabled = true
        settings.borderStyle.width = 4
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        return core
    }

    /// Lands `core` on Space 2 with `one` drawn there as a visitor,
    /// and proves the two regions differ, or the suite reads nothing.
    private func arrive(_ core: KiwiCore) throws -> CGRect {
        core.state.workspaces.ensureSpace(shown)
        core.state.workspaces.setMode(shown, .bsp)
        let display = try #require(core.state.workspaces.allDisplays.first)
        core.resolveSpaceDisplays(mainID: display.id)
        core.state.workspaces.activate(shown)
        core.updateBars()
        expectEqual(core.focusedWindowID, one)
        expectEqual(core.state.workspaces.space(of: one), home)
        expectEqual(core.floatPlacementSpace(of: one), shown)
        let region = try #require(core.floatBounds(on: shown))
        #expect(region != core.floatBounds(of: one))
        #expect(core.floatRingInset > 0)
        return region
    }

    @Test(
        "a sticky traveler centres on the Space it renders on",
        .enabled(if: NSScreen.main != nil)
    )
    func traveler() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        var frames: [WindowID: CGRect] = [:]
        let frame = CGRect(x: 10, y: 200, width: 300, height: 200)
        let core = try #require(makeCore(frame: frame) { frames[$0] = $1 })
        core.execute("make_sticky")
        let region = try arrive(core)
        #expect(core.execute("center_floating").isSuccess)
        expectEqual(frames[one]?.midY, region.midY)
        expectEqual(core.state.workspaces.space(of: one), home)
    }

    /// An axis filling the region reaches the clamp, whose push is
    /// the render Space's strip, not the home's empty list. The bars'
    /// retile fit has already sized it to that region by the press.
    @Test(
        "a traveler's clamp reads the Space it renders on",
        .enabled(if: NSScreen.main != nil)
    )
    func travelerClamp() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        var frames: [WindowID: CGRect] = [:]
        let frame = CGRect(x: 10, y: 60, width: 300, height: 9000)
        let core = try #require(makeCore(frame: frame) { frames[$0] = $1 })
        core.execute("make_sticky")
        let region = try arrive(core)
        #expect(core.execute("center_floating").isSuccess)
        expectEqual(frames[one]?.minY, region.minY + core.floatRingInset)
    }

    /// A window filling the region under a bottom bar: the clamp's
    /// inset push may not carry its title bar above the region.
    @Test(
        "a bottom bar's push leaves the top edge in the region",
        .enabled(if: NSScreen.main != nil)
    )
    func bottomBarKeepsTheTop() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        var frames: [WindowID: CGRect] = [:]
        let frame = CGRect(x: 10, y: 60, width: 300, height: 9000)
        let core = try #require(
            makeCore(frame: frame, edge: .bottom) { frames[$0] = $1 }
        )
        core.execute("make_sticky")
        let region = try arrive(core)
        #expect(core.execute("center_floating").isSuccess)
        expectEqual(frames[one]?.minY, region.minY)
    }

    @Test(
        "an out pocket window centres where it renders, still filed",
        .enabled(if: NSScreen.main != nil)
    )
    func pocketWindow() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        var frames: [WindowID: CGRect] = [:]
        let frame = CGRect(x: 10, y: 200, width: 300, height: 200)
        let core = try #require(makeCore(frame: frame) { frames[$0] = $1 })
        core.execute("toggle_pocket_window")
        expectEqual(core.state.pocketPhase(of: one), .out)
        let region = try arrive(core)
        frames.removeAll()
        #expect(core.execute("center_floating").isSuccess)
        expectEqual(frames[one]?.midY, region.midY)
        expectEqual(core.state.pocketPhase(of: one), .out)
        expectEqual(core.state.workspaces.space(of: one), home)
    }
}
