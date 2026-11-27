import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A renumber of the connected screens (#3647 ▸ lane 2): a pick of a
/// held number swaps two screens, and every screen keeps a number
/// (#3647 ▸ always-numbered ruling).
@Suite("Screen renumbering (#3647)")
struct ScreenRenumberTests {
    private let order = ScreenOrder(["A:1x1", "B:1x1", "C:1x1"])

    @Test("a held number swaps the two screens")
    func swap() throws {
        let next = try #require(order.renumbering("C:1x1", to: 1))
        #expect(next.fingerprints == ["C:1x1", "B:1x1", "A:1x1"])
        #expect(order.renumbering("C:1x1", to: 4) == nil)
        #expect(order.renumbering("Z:1x1", to: 1) == nil)
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

    @Test("a Save stores the order and ends it")
    func save() throws {
        let core = makeCore()
        try loadWork(core)
        core.setSessionScreenOrder(reversed)
        try core.persistProfile(named: "Work", modes: nil)
        let work = try core.profiles.read(name: "Work")
        #expect(work.monitorSets.map(\.monitors) == [reversed.fingerprints])
        #expect(core.profiles.sessionScreenOrder == nil)
        // The stored order answers now; the load's fit was its base's.
        #expect(core.liveScreenOrder == reversed)
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
        core.setSessionScreenOrder(reversed)
        try core.profiles.rename(from: "Work", to: "Desk")
        #expect(core.profiles.sessionScreenOrder?.profile == "Desk")
        #expect(core.liveScreenOrder == reversed)
        try core.profiles.delete(name: "Desk")
        #expect(core.profiles.sessionScreenOrder == nil)
    }

    @Test("a Save under another name hands it over")
    func saveUnderAnotherName() throws {
        let core = makeCore()
        try loadWork(core)
        try core.persistProfile(named: "Other", modes: nil)
        try core.loadProfile(named: "Work")
        core.setSessionScreenOrder(reversed)
        try core.persistProfile(named: "Other", modes: nil)
        #expect(core.profiles.currentName == "Other")
        // Work owns the setup, so Other stores no order to end it.
        #expect(core.profiles.sessionScreenOrder?.profile == "Other")
        #expect(core.liveScreenOrder == reversed)
    }

    /// A screen joining on the LEFT of a held setup takes the next
    /// number, the held screens keeping theirs (#3648 ▸
    /// known-screens ruling).
    @Test("a newcomer on the left keeps the known numbers")
    func newcomerOnTheLeft() throws {
        let core = makeCore()
        try loadWork(core)
        let newcomer = Display(
            id: DisplayID(3),
            name: "C",
            frame: CGRect(x: -400, y: 0, width: 400, height: 400)
        )
        core.handle(.displaysChanged([newcomer, left, right]))
        #expect(core.screenNumber(of: left.id) == 1)
        #expect(core.screenNumber(of: right.id) == 2)
        #expect(core.screenNumber(of: newcomer.id) == 3)
        #expect(core.spacePins["2"] == "B:400x400")
    }

    /// A screen past the profile's numbers takes the next one, its
    /// heal-seeded Space and pin stored like any other number's
    /// (#3647 ▸ always-numbered ruling).
    @Test("an extra screen takes the next number, stored as any other")
    func extraScreenIsStored() throws {
        let core = makeCore()
        try loadWork(core)
        let extra = Display(
            id: DisplayID(3),
            name: "C",
            frame: CGRect(x: 800, y: 0, width: 400, height: 400)
        )
        core.handle(.displaysChanged([left, right, extra]))
        #expect(core.screenNumber(of: extra.id) == 3)
        let seed = try #require(
            core.state.workspaces.spaces(on: extra.id).first
        )
        #expect(core.spacePins[seed] == extra.fingerprint)
        #expect(
            core.storedPins()[seed] == ScreenSlotKey(number: 3)
        )
        try core.persistProfile(named: "Three", modes: nil)
        let three = try core.profiles.read(name: "Three")
        #expect(three.spaces.contains(seed))
        #expect(three.spaceMonitorMap[seed] == ScreenSlotKey(number: 3))
        #expect(
            three.monitorSets.map(\.monitors)
                == [["A:400x400", "B:400x400", "C:400x400"]]
        )
    }
}
