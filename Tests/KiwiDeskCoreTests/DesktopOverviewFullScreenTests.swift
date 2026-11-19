import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A window in macOS full screen lists on KiwiHub's Desktops side
/// as an icon on its Space's line, its pick-up refused (#3486):
/// away on its full-screen Space it lists on the shown Desktop of
/// its screen, and with that Space in front the Desktop the live
/// Spaces hold lists its members and its away windows. Two screens:
/// Built-in (A, Desktops 10 and 11, full-screen Space 12) and DELL
/// (B, Desktops 20 and 21, full-screen Space 22).
@Suite("Desktop overview ▸ full-screen windows", .serialized)
@MainActor
struct DesktopOverviewFullScreenTests {
    private func topology(
        frontA: UInt64 = 10,
        frontB: UInt64 = 20
    ) -> [NativeSpace] {
        func space(_ id: UInt64, _ uuid: String, user: Bool = true)
            -> NativeSpace
        {
            authoritySpace(
                id,
                display: uuid,
                current: id == frontA || id == frontB,
                isUser: user
            )
        }
        return [
            space(10, "UUID-A"), space(11, "UUID-A"),
            space(12, "UUID-A", user: false),
            space(20, "UUID-B"), space(21, "UUID-B"),
            space(22, "UUID-B", user: false),
        ]
    }

    /// Files a switch's reading as the handler does: the shown
    /// map, then the toggle's Desktop record it keeps through a
    /// full-screen Space.
    private func arrive(
        _ core: KiwiCore,
        frontA: UInt64 = 10,
        frontB: UInt64 = 20
    ) {
        NativeSpaces.spacesOverride = topology(
            frontA: frontA,
            frontB: frontB
        )
        core.desktopMemory.fileShown(core.desktopMemory.readDesktops())
        core.refileTilingToggles()
    }

    private func makeCore(frontA: UInt64 = 10, frontB: UInt64 = 20)
        -> KiwiCore
    {
        NativeSpaces.spacesOverride = topology()
        pinTwoDisplays()
        PositionalDisplays.mainIDOverride = { DisplayID(1) }
        let core = makeAuthorityCore()
        connectAuthority(
            core,
            [
                authorityDisplay(1, "Built-in"),
                authorityDisplay(2, "DELL", x: -100),
            ]
        )
        for space in ["1", "2", "5"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.assign("2", to: DisplayID(1))
        core.state.workspaces.assign("5", to: DisplayID(2))
        core.state.workspaces.activate("1")
        arrive(core)
        arrive(core, frontA: frontA, frontB: frontB)
        return core
    }

    private func reset() {
        resetAuthorityOverrides()
        PositionalDisplays.mainIDOverride = nil
    }

    private func track(
        _ core: KiwiCore,
        _ id: UInt32,
        in space: SpaceID,
        fullScreen: Bool = false
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: 900_310,
            appName: "A"
        )
        window.isFullscreen = fullScreen
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(id), to: space)
    }

    private func away(
        _ core: KiwiCore,
        _ id: UInt32,
        on native: UInt64,
        in space: SpaceID?
    ) {
        core.state.awayWindows[WindowID(id)] = AwayWindow(
            id: WindowID(id),
            pid: 900_310,
            appName: "A",
            appBundleID: nil,
            nativeSpace: native
        )
        if let space {
            core.state.rememberedSpaces[WindowID(id)] = .departed(space)
        }
    }

    private func builtIn(_ core: KiwiCore) -> DesktopOverview.Screen {
        core.desktopOverview(on: DisplayID(1)).screens[1]
    }

    @Test("an away full-screen window lists on its Space's line")
    func awayFullScreenListsOnItsLine() throws {
        let core = makeCore()
        defer { reset() }
        track(core, 1, in: "1")
        away(core, 3, on: 12, in: "1")
        away(core, 4, on: 12, in: nil)
        let desktops = builtIn(core).desktops
        try #require(desktops.count == 2)
        let shown = desktops[0]
        try #require(shown.spaces.count == 3)
        #expect(shown.isShown)
        #expect(shown.spaces.map(\.space) == ["1", "2", nil])
        let line = shown.spaces[0]
        #expect(line.windows.map(\.id) == [WindowID(1), WindowID(3)])
        #expect(line.windows.map(\.block) == [nil, .fullScreen])
        // One no Space holds closes the card, refused the same way.
        #expect(shown.spaces[2].windows.map(\.id) == [WindowID(4)])
        #expect(shown.spaces[2].windows.map(\.block) == [.fullScreen])
    }

    @Test("with a full-screen Space in front, the live Desktop lists all")
    func fullScreenInFront() throws {
        let core = makeCore(frontA: 12)
        defer { reset() }
        track(core, 1, in: "1", fullScreen: true)
        away(core, 2, on: 10, in: "1")
        away(core, 5, on: 11, in: "2")
        let desktops = builtIn(core).desktops
        // The screen shows neither Desktop: no check.
        #expect(desktops.map(\.isShown) == [false, false])
        #expect(desktops.map(\.holdsLive) == [true, false])
        try #require(desktops.count == 2)
        try #require(desktops.allSatisfy { $0.spaces.count == 2 })
        let live = desktops[0]
        let ids = live.spaces[0].windows.map(\.id)
        #expect(ids == [WindowID(1), WindowID(2)])
        #expect(live.spaces[0].windows.first?.block == .fullScreen)
        #expect(live.spaces.map(\.isShown) == [true, false])
        // The other Desktop keeps its away reading.
        #expect(desktops[1].spaces[1].windows.map(\.id) == [WindowID(5)])
        #expect(desktops[1].spaces[0].windows.isEmpty)
    }

    @Test("a full-screen Space on B leaves A's Desktops as they are")
    func otherScreenUntouched() throws {
        let core = makeCore(frontB: 22)
        defer { reset() }
        track(core, 1, in: "1")
        away(core, 3, on: 22, in: "5")
        let screens = core.desktopOverview(on: DisplayID(1)).screens
        try #require(screens.count == 2)
        let builtIn = screens[1].desktops
        try #require(builtIn.count == 2 && !builtIn[0].spaces.isEmpty)
        #expect(builtIn.map(\.isShown) == [true, false])
        #expect(builtIn[0].spaces[0].windows.map(\.id) == [WindowID(1)])
        let onA = builtIn.flatMap(\.spaces).flatMap(\.windows)
        #expect(!onA.contains { $0.id == WindowID(3) })
        let dell = screens[0].desktops
        try #require(dell.count == 2 && !dell[0].spaces.isEmpty)
        #expect(dell.map(\.isShown) == [false, false])
        #expect(dell[0].spaces[0].windows.map(\.id) == [WindowID(3)])
        #expect(dell[0].spaces[0].windows.map(\.block) == [.fullScreen])
    }

    @Test("the held Desktop follows the last Desktop a switch showed")
    func heldDesktopFollowsTheSwitch() {
        let core = makeCore()
        defer { reset() }
        func held(_ display: UInt32) -> UInt64? {
            core.heldDesktop(
                on: DisplayID(display),
                in: core.desktopMemory.readDesktops()
            )
        }
        func holds(_ native: UInt64) -> Bool {
            core.holdsLive(native, in: core.desktopMemory.readDesktops())
        }
        #expect(held(1) == nil)
        arrive(core, frontA: 12)
        #expect(held(1) == 10)
        #expect(held(2) == nil)
        arrive(core, frontA: 11)
        arrive(core, frontA: 12)
        #expect(held(1) == 11)
        #expect(holds(11))
        #expect(!holds(10))
    }

    @Test("with no switch filed, the screen's first Desktop holds them")
    func heldFallsBackToTheFirstDesktop() throws {
        let core = makeCore(frontA: 12)
        defer { reset() }
        core.desktopMemory.tilingToggleDesktop = [:]
        track(core, 1, in: "1", fullScreen: true)
        let desktops = builtIn(core).desktops
        #expect(desktops.map(\.holdsLive) == [true, false])
        try #require(desktops.first?.spaces.isEmpty == false)
        #expect(desktops[0].spaces[0].windows.map(\.id) == [WindowID(1)])
        // A record naming no Desktop of the screen falls back too.
        core.desktopMemory.tilingToggleDesktop = ["1": 99, "2": 99]
        #expect(
            core.heldDesktop(
                on: DisplayID(1),
                in: core.desktopMemory.readDesktops()
            ) == 10
        )
    }

    @Test("with shared Desktops, a full-screen window lists once")
    func sharedListsOnce() throws {
        let core = makeCore()
        defer { reset() }
        NativeSpaces.spacesOverride = [
            authoritySpace(10, display: "SHARED", current: true),
            authoritySpace(11, display: "SHARED"),
            authoritySpace(12, display: "SHARED", isUser: false),
        ]
        away(core, 3, on: 12, in: "5")
        let screens = core.desktopOverview(on: DisplayID(1)).screens
        try #require(
            screens.count == 2
                && screens.allSatisfy { !$0.desktops.isEmpty }
        )
        let lines = screens.map { $0.desktops[0].spaces }
        try #require(!lines[0].isEmpty)
        // DELL lists it on its Space 5; Built-in leaves it there.
        #expect(lines[0][0].windows.map(\.id) == [WindowID(3)])
        #expect(lines[1].allSatisfy { $0.windows.isEmpty })
    }

    @Test("a move on the held Desktop files the window, as on a shown one")
    func heldMoveFiles() {
        let core = makeCore(frontA: 12)
        defer { reset() }
        track(core, 1, in: "1")
        #expect(
            core.overviewMove(
                WindowID(1),
                into: "2",
                onDesktop: 10,
                follow: false
            )
        )
        #expect(core.state.workspaces.space(of: WindowID(1)) == "2")
    }
}
