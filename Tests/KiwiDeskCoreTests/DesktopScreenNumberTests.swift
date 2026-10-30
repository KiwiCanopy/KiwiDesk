import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop's label number is its place on its own screen, as
/// Mission Control numbers each screen's strip (#2792 ▸ Ruling);
/// KiwiHub names the screen of a row off its own screen.
@Suite("Desktop number per screen", .serialized)
@MainActor
struct DesktopScreenNumberTests {
    @Test("a second screen's Desktops count from 1")
    func screenNumber() {
        defer { resetAuthorityOverrides() }
        let snapshot = authoritySnapshot()
        #expect(snapshot.screenNumber(of: 10) == 1)
        #expect(snapshot.screenNumber(of: 11) == 2)
        #expect(snapshot.screenNumber(of: 20) == 1)
        #expect(snapshot.screenNumber(of: 21) == 2)
        // Verbs keep counting globally.
        #expect(snapshot.number(of: 21) == 4)
        #expect(snapshot.screenNumber(of: 99) == nil)
    }

    @Test("a non-user Space takes no number and shifts none")
    func fullscreenSkipped() {
        let spaces = [
            authoritySpace(20, display: "B"),
            authoritySpace(30, display: "B", isUser: false),
            authoritySpace(21, display: "B"),
        ]
        #expect(NativeSpaces.screenNumber(of: 21, in: spaces) == 2)
        #expect(NativeSpaces.screenNumber(of: 30, in: spaces) == nil)
    }

    @Test("every key a Desktop answers to carries its screen number")
    func numbersByKey() {
        defer { resetAuthorityOverrides() }
        let snapshot = authoritySnapshot()
        let numbers = snapshot.screenNumbersByKey
        #expect(numbers[.number(4)] == 2)
        #expect(numbers[.number(3)] == 1)
        #expect(numbers[.number(1)] == 1)
    }

    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
        let core = makeAuthorityCore()
        connectAuthority(
            core,
            [
                authorityDisplay(1, "Built-in"),
                authorityDisplay(2, "DELL U2723", x: 100),
            ]
        )
        for space in ["1", "5"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.assign("5", to: DisplayID(2))
        core.state.workspaces.activate("1")
        return core
    }

    private func track(_ core: KiwiCore, _ id: UInt32, in space: SpaceID) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(id), pid: 900_200, appName: "A")
            )
        )
        core.state.workspaces.add(WindowID(id), to: space)
    }

    private func row(_ core: KiwiCore, _ id: UInt32, on hub: DisplayID)
        -> JumpEntry?
    {
        core.jumpSnapshot(on: hub).entries.first {
            $0.target == .window(WindowID(id))
        }
    }

    @Test("a row names the screen only off KiwiHub's own")
    func shownRowsNameTheOtherScreen() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, in: "1")
        track(core, 2, in: "5")
        let dell = ScreenLabel(name: "DELL U2723")
        #expect(row(core, 2, on: DisplayID(1))?.screen == dell)
        #expect(row(core, 1, on: DisplayID(1))?.screen == nil)
        #expect(
            row(core, 1, on: DisplayID(2))?.screen
                == ScreenLabel(name: "Built-in")
        )
    }

    @Test("an away row takes its screen and its number there")
    func awayRow() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        core.state.awayWindows[WindowID(7)] = AwayWindow(
            id: WindowID(7),
            pid: 900_200,
            appName: "A",
            appBundleID: nil,
            nativeSpace: 21
        )
        core.desktopMemory.readCensus = { spaces in
            DesktopCensus(
                hosts: [
                    WindowID(7): DesktopCensus.Host(
                        space: 21,
                        pid: 900_200,
                        isUp: true
                    )
                ],
                shown: Set(spaces.filter(\.isCurrent).map(\.id))
            )
        }
        let away = row(core, 7, on: DisplayID(1))
        #expect(away?.status == .away(desktop: 2))
        #expect(away?.screen == ScreenLabel(name: "DELL U2723"))
    }

    @Test("a global number says where it lands")
    func landings() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        let landings = core.desktopLandings(in: NativeSpaces.desktopSnapshot())
        let dell = ScreenLabel(name: "DELL U2723")
        #expect(landings[3] == DesktopLanding(screen: dell, number: 1))
        #expect(landings[4] == DesktopLanding(screen: dell, number: 2))
        #expect(landings[1]?.number == 1)
        #expect(landings[5] == nil)
    }

    @Test("one screen names none; twins take their place")
    func labels() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        #expect(core.screenLabel(of: DisplayID(2))?.twinPlace == nil)
        core.state.workspaces.upsertDisplay(
            authorityDisplay(2, "Built-in", x: 100)
        )
        #expect(
            core.screenLabel(of: DisplayID(1))
                == ScreenLabel(name: "Built-in", twinPlace: 0)
        )
        #expect(core.screenLabel(of: DisplayID(2))?.twinPlace == 1)
        _ = core.state.workspaces.removeDisplay(DisplayID(2))
        #expect(core.screenLabel(of: DisplayID(1)) == nil)
    }
}
