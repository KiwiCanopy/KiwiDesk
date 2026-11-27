import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A renumber of the connected screens (#3647 ▸ lane 2): a pick of a
/// held number swaps two screens, a screen left unnumbered gives up
/// its number for the session, and a twin cannot be left unnumbered.
@Suite("Screen renumbering (#3647)")
struct ScreenRenumberTests {
    private let order = ScreenOrder(["A:1x1", "B:1x1", "C:1x1"])

    @Test("a held number swaps the two screens")
    func swap() throws {
        let next = try #require(order.renumbering("C:1x1", to: 1))
        #expect(next.fingerprints == ["C:1x1", "B:1x1", "A:1x1"])
        #expect(next.unnumbered.isEmpty)
        #expect(order.renumbering("C:1x1", to: 4) == nil)
        #expect(order.renumbering("Z:1x1", to: 1) == nil)
    }

    @Test("an unnumbered screen gives up its own number alone")
    func hole() throws {
        let next = try #require(order.unnumbering("B:1x1"))
        #expect(next.fingerprints == order.fingerprints)
        #expect(next.unnumbered == [2])
        #expect(!next.holds(ScreenSlotKey(number: 2)!))
        #expect(next.holds(ScreenSlotKey(number: 3)!))
        #expect(next.runtimeKey(of: ScreenSlotKey(number: 2)!) == nil)
        #expect(
            next.slot(of: ScreenAreaKey(fingerprint: "B:1x1", areaID: 0))
                == nil
        )
        // Its stored pin waits; a runtime pin to it is dropped.
        let stored = next.storing(
            runtime: ["9": "B:1x1"],
            over: ["2": ScreenSlotKey(number: 2)!]
        )
        #expect(stored == ["2": ScreenSlotKey(number: 2)!])
    }

    @Test("picking a number numbers an unnumbered screen again")
    func renumberTheHole() throws {
        let holed = try #require(order.unnumbering("B:1x1"))
        let own = try #require(holed.renumbering("B:1x1", to: 2))
        #expect(own == order)
        let swapped = try #require(holed.renumbering("B:1x1", to: 1))
        #expect(swapped.fingerprints == ["B:1x1", "A:1x1", "C:1x1"])
        #expect(swapped.unnumbered.isEmpty)
    }

    @Test("a twin cannot be left unnumbered")
    func twins() {
        let twins = ScreenOrder(["T:1x1", "T:1x1"])
        #expect(twins.unnumbering("T:1x1") == nil)
    }
}

/// The session override's reach: the live profile on the setup it
/// was made on, never a stored profile's own order, and cleared only
/// where profiles.md says.
@Suite("The session screen order (#3647)", .serialized)
@MainActor
struct SessionScreenOrderTests {
    private let left = Display(
        id: DisplayID(1),
        name: "A",
        frame: CGRect(x: 0, y: 0, width: 400, height: 400)
    )
    private let right = Display(
        id: DisplayID(2),
        name: "B",
        frame: CGRect(x: 400, y: 0, width: 400, height: 400)
    )
    private let reversed = ScreenOrder(["B:400x400", "A:400x400"])

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647s-\(UUID().uuidString)")
        )
    }

    /// "Work" holds A–B in that order, Space 2 pinned to Screen 2.
    private func loadWork(_ core: KiwiCore) throws {
        core.handle(.displaysChanged([left, right]))
        try core.profiles.write(
            Profile(
                name: "Work",
                monitorSets: [
                    MonitorSet(monitors: ["A:400x400", "B:400x400"])
                ],
                spaceMonitorMap: ["2": ScreenSlotKey(number: 2)!],
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                settings: TilingSettings()
            )
        )
        try core.loadProfile(named: "Work")
        #expect(core.spacePins["2"] == "B:400x400")
    }

    @Test("the live profile reads it; a stored order never does")
    func reach() throws {
        let core = makeCore()
        try loadWork(core)
        core.setSessionScreenOrder(reversed)
        #expect(core.liveScreenOrder == reversed)
        let work = try core.profiles.read(name: "Work")
        #expect(core.screenOrder(for: work) == reversed)
        #expect(core.screenOrder(holding: work.monitorSets) != reversed)
        #expect(core.runtimePins(of: work)["2"] == "A:400x400")
        // Another setup: inert.
        core.handle(.displaysChanged([left]))
        #expect(core.liveScreenOrder != reversed)
    }

    /// A split belongs to its number (#3647 ▸ lane 3): a renumber
    /// moves Screen 1's split to whichever screen now holds 1.
    @Test("a renumber moves a number's split with it")
    func splitFollowsTheNumber() throws {
        let core = makeCore()
        try loadWork(core)
        // Halves of a 400-pt screen, under a floor they clear.
        core.tiler.settings.minWindowSizes = MinWindowSizes(
            all: .square(100)
        )
        let halves = ScreenSplit(
            areas: [
                ScreenArea(id: 0, x: 0, y: 0, w: 200, h: 400),
                ScreenArea(id: 1, x: 200, y: 0, w: 200, h: 400),
            ]
        )
        core.tiler.settings.displayAreas.store(
            halves,
            on: left.fingerprint,
            order: core.liveScreenOrder
        )
        let splits = { core.state.workspaces.areaSplits }
        #expect(splits()[left.fingerprint] != nil)
        #expect(splits()[right.fingerprint] == nil)
        core.setSessionScreenOrder(reversed)
        #expect(splits()[left.fingerprint] == nil)
        #expect(splits()[right.fingerprint]?.areas.count == 2)
    }

    /// An apply lays its splits out in its own numbering, as its
    /// pins, though the name moves last (#3647 ▸ lane 3).
    @Test("a profile switch lays out its own screen numbers")
    func profileSwitchLaysOutItsOwnNumbers() throws {
        let core = makeCore()
        try loadWork(core)
        var settings = TilingSettings()
        settings.minWindowSizes = MinWindowSizes(all: .square(100))
        settings.displayAreas[number: 1] = ScreenShares(
            areas: [
                ScreenArea(id: 0, x: 0, y: 0, w: 500, h: 1000),
                ScreenArea(id: 1, x: 500, y: 0, w: 500, h: 1000),
            ]
        )
        try core.profiles.write(
            Profile(
                name: "Other",
                monitorSets: [MonitorSet(monitors: reversed.fingerprints)],
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                settings: settings
            )
        )
        try core.loadProfile(named: "Other")
        // B is Other's Screen 1.
        let splits = core.state.workspaces.areaSplits
        #expect(splits[right.fingerprint]?.areas.count == 2)
        #expect(splits[left.fingerprint] == nil)
    }

    @Test("a Save stores the order and ends it; a hole outlives it")
    func save() throws {
        let core = makeCore()
        try loadWork(core)
        core.setSessionScreenOrder(reversed)
        try core.persistProfile(named: "Work", modes: nil)
        var work = try core.profiles.read(name: "Work")
        #expect(work.monitorSets.map(\.monitors) == [reversed.fingerprints])
        #expect(core.profiles.sessionScreenOrder == nil)
        // The stored order answers now; the load's fit was its base's.
        #expect(core.liveScreenOrder == reversed)
        let holed = try #require(reversed.unnumbering("A:400x400"))
        core.setSessionScreenOrder(holed)
        try core.persistProfile(named: "Work", modes: nil)
        work = try core.profiles.read(name: "Work")
        #expect(work.monitorSets.map(\.monitors) == [reversed.fingerprints])
        #expect(core.profiles.sessionScreenOrder?.order == holed)
    }

    @Test("an explicit load ends it; a monitor change does not")
    func clears() throws {
        let core = makeCore()
        try loadWork(core)
        core.setSessionScreenOrder(reversed)
        core.handle(.displaysChanged([left, right]))
        #expect(core.profiles.sessionScreenOrder?.order == reversed)
        try core.loadProfile(named: "Work")
        #expect(core.profiles.sessionScreenOrder == nil)
    }

    @Test("another profile on the same screens never reads it")
    func ownedByItsProfile() throws {
        let core = makeCore()
        try loadWork(core)
        core.setSessionScreenOrder(reversed)
        let home = Profile(
            name: "Home",
            monitorSets: [MonitorSet(monitors: ["A:400x400", "B:400x400"])],
            spaceMonitorMap: ["2": ScreenSlotKey(number: 2)!],
            spaces: ["1", "2"],
            spaceModes: ["1": .bsp, "2": .bsp],
            settings: TilingSettings()
        )
        try core.profiles.write(home)
        core.apply(profile: home, cause: .event)
        #expect(core.profiles.currentName == "Home")
        #expect(core.liveScreenOrder.fingerprints.first == "A:400x400")
        #expect(core.spacePins["2"] == "B:400x400")
    }

    @Test("an unnumbered screen answers to no number")
    func holeNamesNothing() throws {
        let core = makeCore()
        try loadWork(core)
        let holed = try #require(
            ScreenOrder(["A:400x400", "B:400x400"])
                .unnumbering("B:400x400")
        )
        core.setSessionScreenOrder(holed)
        #expect(core.screen(numbered: 1)?.id == left.id)
        #expect(core.screen(numbered: 2) == nil)
        #expect(core.screenNumber(of: right.id) == nil)
    }

    @Test("a new profile stores no pin to an unnumbered screen")
    func newProfileDropsTheHolePin() throws {
        let core = makeCore()
        try loadWork(core)
        let holed = try #require(
            ScreenOrder(["A:400x400", "B:400x400"])
                .unnumbering("B:400x400")
        )
        core.setSessionScreenOrder(holed)
        core.spacePins = ["2": "B:400x400"]
        try core.persistProfile(named: "Fresh", modes: nil)
        let fresh = try core.profiles.read(name: "Fresh")
        #expect(fresh.spaceMonitorMap.isEmpty)
        #expect(
            fresh.monitorSets.map(\.monitors) == [["A:400x400", "B:400x400"]]
        )
    }

    @Test("a pick of the connected set and the reset end it")
    func pickAndResetClear() throws {
        let core = makeCore()
        try loadWork(core)
        core.setSessionScreenOrder(reversed)
        try core.claimMonitorSet(["A:400x400", "B:400x400"], for: "Work")
        #expect(core.profiles.sessionScreenOrder == nil)
        core.setSessionScreenOrder(reversed)
        _ = core.resetAllSettings(trash: { _ in })
        #expect(core.profiles.sessionScreenOrder == nil)
    }

    @Test("a renumber saved as new leaves the old profile its order")
    func saveAsNewTakesTheOrder() throws {
        let core = makeCore()
        try loadWork(core)
        core.setSessionScreenOrder(reversed)
        try core.persistProfile(named: "Copy", modes: nil)
        let copy = try core.profiles.read(name: "Copy")
        #expect(copy.monitorSets.map(\.monitors) == [reversed.fingerprints])
        #expect(core.profiles.sessionScreenOrder == nil)
        let work = try core.profiles.read(name: "Work")
        core.apply(profile: work, cause: .event)
        #expect(core.liveScreenOrder.fingerprints.first == "A:400x400")
    }

    @Test("a rename keeps it with its profile; a delete drops it")
    func renameAndDelete() throws {
        let core = makeCore()
        try loadWork(core)
        let holed = try #require(reversed.unnumbering("A:400x400"))
        core.setSessionScreenOrder(holed)
        try core.profiles.rename(from: "Work", to: "Desk")
        #expect(core.profiles.sessionScreenOrder?.profile == "Desk")
        #expect(core.liveScreenOrder == holed)
        try core.profiles.delete(name: "Desk")
        #expect(core.profiles.sessionScreenOrder == nil)
    }

    @Test("a Save under another name hands it over")
    func saveUnderAnotherName() throws {
        let core = makeCore()
        try loadWork(core)
        try core.persistProfile(named: "Other", modes: nil)
        try core.loadProfile(named: "Work")
        let holed = try #require(reversed.unnumbering("A:400x400"))
        core.setSessionScreenOrder(holed)
        try core.persistProfile(named: "Other", modes: nil)
        #expect(core.profiles.currentName == "Other")
        #expect(core.profiles.sessionScreenOrder?.profile == "Other")
        #expect(core.liveScreenOrder == holed)
    }
}
