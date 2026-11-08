import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's Desktops side reads the whole desk at once (#1229): a
/// row per screen in physical order, each screen's Desktops, the
/// screen's Spaces on each, members where the Desktop shows and the
/// away ledger where it does not. Two screens: Built-in (A, main,
/// Desktops 10 and 11) right of DELL (B, Desktops 20 and 21).
@Suite("Desktop overview reading", .serialized)
@MainActor
struct DesktopOverviewTests {
    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
        PositionalDisplays.mainIDOverride = { DisplayID(1) }
        let core = makeAuthorityCore()
        connectAuthority(
            core,
            [
                authorityDisplay(1, "Built-in"),
                // Left of Built-in and below it: left to right comes
                // first, so a sort by height alone reds.
                Display(
                    id: DisplayID(2),
                    name: "DELL",
                    frame: CGRect(x: -100, y: -50, width: 100, height: 100)
                ),
            ]
        )
        for space in ["1", "2", "5"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.assign("2", to: DisplayID(1))
        core.state.workspaces.assign("5", to: DisplayID(2))
        core.state.workspaces.activate("1")
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
            pid: 900_300,
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
        in space: SpaceID?,
        up: Bool = true
    ) {
        var entry = AwayWindow(
            id: WindowID(id),
            pid: 900_300,
            appName: "A",
            appBundleID: nil,
            nativeSpace: native
        )
        entry.isUp = up
        core.state.awayWindows[WindowID(id)] = entry
        if let space {
            core.state.rememberedSpaces[WindowID(id)] = .departed(space)
        }
    }

    @Test("rows run left to right, marked main and here, never moved")
    func screensInPhysicalOrder() {
        let core = makeCore()
        defer { reset() }
        let overview = core.desktopOverview(on: DisplayID(1))
        #expect(overview.screens.map(\.name) == ["DELL", "Built-in"])
        #expect(overview.screens.map(\.isMain) == [false, true])
        #expect(overview.screens.map(\.isHere) == [false, true])
    }

    @Test("each screen lists its own Desktops, labelled on that screen")
    func desktopsPerScreen() {
        let core = makeCore()
        defer { reset() }
        let screens = core.desktopOverview(on: DisplayID(1)).screens
        let dell = screens[0].desktops
        #expect(dell.map(\.native) == [20, 21])
        #expect(dell.map(\.label) == [1, 2])
        #expect(dell.map(\.number) == [3, 4])
        #expect(dell.map(\.isShown) == [true, false])
        #expect(screens[1].desktops.map(\.native) == [10, 11])
    }

    @Test("a shown Desktop lists every Space of its screen and members")
    func shownDesktopLines() {
        let core = makeCore()
        defer { reset() }
        track(core, 1, in: "1")
        track(core, 2, in: "1", fullScreen: true)
        let desktop = core.desktopOverview(on: DisplayID(1))
            .screens[1].desktops[0]
        #expect(desktop.spaces.map(\.space) == ["1", "2"])
        #expect(desktop.spaces.map(\.isShown) == [true, false])
        let line = desktop.spaces[0]
        #expect(line.windows.map(\.id) == [WindowID(1), WindowID(2)])
        #expect(line.windows.map(\.block) == [nil, .fullScreen])
        #expect(desktop.spaces[1].windows.isEmpty)
    }

    @Test("a hidden Desktop lists its up away windows in their Spaces")
    func hiddenDesktopLines() {
        let core = makeCore()
        defer { reset() }
        away(core, 7, on: 11, in: "2")
        away(core, 8, on: 11, in: nil)
        away(core, 9, on: 11, in: "1", up: false)
        away(core, 6, on: 10, in: "1")
        let desktop = core.desktopOverview(on: DisplayID(1))
            .screens[1].desktops[1]
        #expect(desktop.spaces.map(\.space) == ["1", "2", nil])
        #expect(desktop.spaces[0].windows.isEmpty)
        #expect(desktop.spaces[1].windows.map(\.id) == [WindowID(7)])
        #expect(desktop.spaces[1].windows.first?.block == .otherDesktop)
        // Unfiled windows close the card on a line of their own.
        #expect(desktop.spaces[2].windows.map(\.id) == [WindowID(8)])
    }

    @Test("a hidden Desktop's Space names its last-focused window there")
    func hiddenLastFocused() {
        let core = makeCore()
        defer { reset() }
        away(core, 7, on: 11, in: "2")
        core.desktopMemory.honoredFocus["2"] = [11: WindowID(7)]
        let line = core.desktopOverview(on: DisplayID(1))
            .screens[1].desktops[1].spaces[1]
        #expect(line.lastFocused == WindowID(7))
    }
}
