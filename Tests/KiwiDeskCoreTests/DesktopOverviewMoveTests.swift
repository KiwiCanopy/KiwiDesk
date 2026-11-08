import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktops side's doors pick their route at the press from a
/// fresh reading (#1229), and with shared Desktops each screen lists
/// a hidden Desktop's window once. Two screens as in
/// `DesktopOverviewTests`: Built-in (A, Desktops 10 and 11) and
/// DELL (B, Desktops 20 and 21).
@Suite("Desktop overview moves", .serialized)
@MainActor
struct DesktopOverviewMoveTests {
    private func makeCore(shared: Bool = false) -> KiwiCore {
        NativeSpaces.spacesOverride =
            shared
            ? [
                authoritySpace(10, display: "SHARED", current: true),
                authoritySpace(11, display: "SHARED"),
            ]
            : authorityTopology(mainCurrent: 10, secondaryCurrent: 20)
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
        return core
    }

    private func reset() {
        resetAuthorityOverrides()
        PositionalDisplays.mainIDOverride = nil
    }

    @Test("a Desktop is shown where its screen shows it, now")
    func shownIsRead() {
        defer { reset() }
        let snapshot = authoritySnapshot()
        #expect(KiwiCore.isShown(10, in: snapshot))
        #expect(!KiwiCore.isShown(11, in: snapshot))
        #expect(!KiwiCore.isShown(99, in: snapshot))
        let none = DesktopSnapshot(
            authority: nil,
            mainUUID: nil,
            mainCurrentSpace: nil,
            currentSpaces: [:],
            spaces: []
        )
        #expect(KiwiCore.isShown(0, in: none))
    }

    @Test("onto a shown Desktop a window moves into the Space")
    func shownMoveFiles() {
        let core = makeCore()
        defer { reset() }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 900_300, appName: "A")
            )
        )
        core.state.workspaces.add(WindowID(1), to: "1")
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

    @Test("a Desktop macOS does not number is reached by no move")
    func unnumberedRefuses() {
        let core = makeCore()
        defer { reset() }
        #expect(
            !core.overviewMove(
                WindowID(1),
                into: "2",
                onDesktop: 99,
                follow: false
            )
        )
    }

    @Test("with shared Desktops a hidden window is listed once")
    func sharedListsOnce() {
        let core = makeCore(shared: true)
        defer { reset() }
        var entry = AwayWindow(
            id: WindowID(7),
            pid: 900_300,
            appName: "A",
            appBundleID: nil,
            nativeSpace: 11
        )
        entry.isUp = true
        core.state.awayWindows[WindowID(7)] = entry
        core.state.rememberedSpaces[WindowID(7)] = .departed("5")
        let screens = core.desktopOverview(on: DisplayID(1)).screens
        let listed = screens.flatMap { screen in
            screen.desktops.filter { $0.native == 11 }
                .flatMap(\.spaces).flatMap(\.windows).map(\.id)
        }
        #expect(listed == [WindowID(7)])
    }
}
