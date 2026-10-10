import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop switch cue (#2142): owed only by KiwiDesk's own
/// switch, paid by the switch handler once the target is shown,
/// carrying the global number, the screen's dots and a profile
/// only where one loaded. Over the #888 fixture: Desktops 1–2 on
/// `UUID-A` (ids 10, 11), 3–4 on `UUID-B` (ids 20, 21).
@Suite("Desktop switch cue (#2142)", .serialized)
@MainActor
struct DesktopSwitchCueTests {
    private let at = Date(timeIntervalSince1970: 1000)

    private func owed(
        _ space: SkyLight.SpaceID,
        on uuid: String,
        at time: Date? = nil
    ) -> DesktopCueLedger.Owed {
        .init(displayUUID: uuid, space: space, at: time ?? at)
    }

    @Test("a second screen's Desktop keeps its global number")
    func globalNumberLocalDots() {
        defer { resetAuthorityOverrides() }
        let snapshot = authoritySnapshot(mainCurrent: 10, secondaryCurrent: 21)
        let cue = DesktopCueLedger.cue(
            for: owed(21, on: "UUID-B"),
            in: snapshot,
            display: DisplayID(2),
            loadedProfile: "Work",
            now: at.addingTimeInterval(0.2)
        )
        #expect(
            cue
                == DesktopSwitchCue(
                    display: DisplayID(2),
                    number: 4,
                    position: 2,
                    count: 2,
                    loadedProfile: "Work"
                )
        )
    }

    @Test("nothing is earned before the target shows, or past the bound")
    func earnedOnlyWhenShownInTime() {
        defer { resetAuthorityOverrides() }
        let notYet = authoritySnapshot(mainCurrent: 10)
        #expect(
            DesktopCueLedger.cue(
                for: owed(11, on: "UUID-A"),
                in: notYet,
                display: DisplayID(1),
                loadedProfile: nil,
                now: at
            ) == nil
        )
        let shown = authoritySnapshot(mainCurrent: 11)
        let late = at.addingTimeInterval(DesktopCueLedger.bound + 0.1)
        #expect(
            DesktopCueLedger.cue(
                for: owed(11, on: "UUID-A"),
                in: shown,
                display: DisplayID(1),
                loadedProfile: nil,
                now: late
            ) == nil
        )
        #expect(
            DesktopCueLedger.cue(
                for: owed(11, on: "UUID-A"),
                in: shown,
                display: nil,
                loadedProfile: nil,
                now: at
            ) == nil
        )
    }

    // MARK: - Through the switch and the handler

    private func makeCore() -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { desktopVerbBridgeClasses[$0] }
        let core = makeTestCore()
        core.wallClock = { self.at }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Main",
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            )
        )
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// Lands the switch the bridge accepted, as the OS
    /// notification does.
    private func land(_ core: KiwiCore, mainOn space: UInt64) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: space,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = space
        core.handleDesktopChange()
    }

    @Test("focus_desktop owes the cue and its landing pays it once")
    func ownSwitchPays() {
        let core = makeCore()
        defer { teardown() }
        var shown: [DesktopSwitchCue] = []
        core.desktopCue.onCue = { shown.append($0) }
        #expect(core.execute("focus_desktop", args: [.number(2)]).isSuccess)
        #expect(core.desktopCue.owed != nil)
        land(core, mainOn: 11)
        #expect(
            shown == [
                DesktopSwitchCue(
                    display: DisplayID(1),
                    number: 2,
                    position: 2,
                    count: 2,
                    loadedProfile: nil
                )
            ]
        )
        #expect(core.desktopCue.owed == nil)
        land(core, mainOn: 10)
        #expect(shown.count == 1)
    }

    @Test("a gesture switch owes nothing")
    func gestureShowsNothing() {
        let core = makeCore()
        defer { teardown() }
        var shown = 0
        core.desktopCue.onCue = { _ in shown += 1 }
        land(core, mainOn: 11)
        #expect(shown == 0)
    }

    @Test("switched off, the landing still settles the debt")
    func offSettlesSilently() {
        let core = makeCore()
        defer { teardown() }
        var shown = 0
        core.desktopCue.onCue = { _ in shown += 1 }
        #expect(
            core.execute("set_desktop_cue", args: [.bool(false)])
                .isSuccess
        )
        #expect(core.appWide.desktopCue == false)
        core.execute("focus_desktop", args: [.number(2)])
        land(core, mainOn: 11)
        #expect(shown == 0)
        #expect(core.desktopCue.owed == nil)
        #expect(
            !core.execute("set_desktop_cue", args: [.string("no")])
                .isSuccess
        )
    }

    // MARK: - Stored shape

    @Test("gui.json carries desktop.cue, and its absence reads on")
    func storedShape() throws {
        var config = GuiConfig()
        var value = AppWideSettings()
        value.desktopCue = false
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let group = try #require(root["desktop"] as? [String: Any])
        #expect(group["cue"] as? Bool == false)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.desktopCue == false)
        var older = root
        older["desktop"] = nil
        let legacy = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: older)
        )
        #expect(legacy.appWide?.desktopCue == true)
    }
}
