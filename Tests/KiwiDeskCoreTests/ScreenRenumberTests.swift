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
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
    private let right = Display(
        id: DisplayID(2),
        name: "B",
        frame: CGRect(x: 100, y: 0, width: 100, height: 100)
    )
    private let reversed = ScreenOrder(["B:100x100", "A:100x100"])

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
                    MonitorSet(monitors: ["A:100x100", "B:100x100"])
                ],
                spaceMonitorMap: ["2": ScreenSlotKey(number: 2)!],
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                settings: TilingSettings()
            )
        )
        try core.loadProfile(named: "Work")
        #expect(core.spacePins["2"] == "B:100x100")
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
        #expect(core.runtimePins(of: work)["2"] == "A:100x100")
        // Another setup: inert.
        core.handle(.displaysChanged([left]))
        #expect(core.liveScreenOrder != reversed)
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
        let holed = try #require(reversed.unnumbering("A:100x100"))
        core.setSessionScreenOrder(holed)
        try core.persistProfile(named: "Work", modes: nil)
        work = try core.profiles.read(name: "Work")
        #expect(work.monitorSets.map(\.monitors) == [reversed.fingerprints])
        #expect(core.profiles.sessionScreenOrder == holed)
    }

    @Test("an explicit load ends it; a monitor change does not")
    func clears() throws {
        let core = makeCore()
        try loadWork(core)
        core.setSessionScreenOrder(reversed)
        core.handle(.displaysChanged([left, right]))
        #expect(core.profiles.sessionScreenOrder == reversed)
        try core.loadProfile(named: "Work")
        #expect(core.profiles.sessionScreenOrder == nil)
    }
}
