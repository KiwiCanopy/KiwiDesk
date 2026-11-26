import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Every setup of one screen count shares a profile's pins (#3647 ▸
/// Ruling): a pin is stored by the number its screen holds, read
/// onto whichever setup is connected through that setup's order,
/// and a Save numbers it back through the same order.
@Suite("Numbered pins are shared across setups (#3647)", .serialized)
@MainActor
struct NumberedPinsSharedTests {
    private let home = ["A:100x100", "B:100x100"]
    private let cowork = ["C:100x100", "D:100x100"]

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-3647-\(UUID().uuidString)"
                )
        )
    }

    /// Replaces the connected screens with 100x100 ones, left to
    /// right in the order named.
    private func connect(_ core: KiwiCore, _ fingerprints: [String]) {
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        for (index, fingerprint) in fingerprints.enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: Display.fingerprintParts(fingerprint).name,
                    frame: CGRect(
                        x: CGFloat(index) * 100,
                        y: 0,
                        width: 100,
                        height: 100
                    )
                )
            )
        }
    }

    private func work(order cowork: [String]) -> Profile {
        Profile(
            name: "Work",
            monitorSets: [
                MonitorSet(monitors: home),
                MonitorSet(monitors: cowork),
            ],
            spaceMonitorMap: ["2": ScreenSlotKey(number: 2)!],
            spaces: ["1", "2"],
            spaceModes: ["1": .bsp, "2": .bsp],
            settings: TilingSettings()
        )
    }

    @Test("a pin reaches every setup of its count through its order")
    func pinFollowsTheNumber() throws {
        let core = makeCore()
        try core.profiles.write(work(order: cowork))
        connect(core, cowork)
        try core.loadProfile(named: "Work")
        #expect(core.spacePins["2"] == "D:100x100")
        // A stored order is the setup's, wherever its screens sit.
        try core.profiles.write(work(order: cowork.reversed()))
        try core.loadProfile(named: "Work")
        #expect(core.spacePins["2"] == "C:100x100")
    }

    @Test("an edit saved at one setup is there at the other")
    func editReachesTheOtherSetup() throws {
        let core = makeCore()
        try core.profiles.write(work(order: cowork))
        connect(core, home)
        try core.loadProfile(named: "Work")
        core.spacePins = ["1": "B:100x100", "2": "A:100x100"]
        try core.persistProfile(named: "Work", modes: nil)
        let saved = try core.profiles.read(name: "Work")
        #expect(
            saved.spaceMonitorMap == [
                "1": ScreenSlotKey(number: 2)!,
                "2": ScreenSlotKey(number: 1)!,
            ]
        )
        connect(core, cowork)
        try core.loadProfile(named: "Work")
        #expect(
            core.spacePins == ["1": "D:100x100", "2": "C:100x100"]
        )
    }

    /// The Save numbers through the set the profile holds, never the
    /// left-to-right suggestion, or a pin moves screens on reload.
    @Test("a Save numbers through the held set's stored order")
    func saveTakesTheHeldOrder() throws {
        let core = makeCore()
        try core.profiles.write(work(order: cowork.reversed()))
        connect(core, cowork)
        try core.loadProfile(named: "Work")
        core.spacePins = ["1": "C:100x100"]
        try core.persistProfile(named: "Work", modes: nil)
        let saved = try core.profiles.read(name: "Work")
        #expect(saved.spaceMonitorMap == ["1": ScreenSlotKey(number: 2)!])
        #expect(core.liveScreenOrder.fingerprints == cowork.reversed())
    }

    /// A Save that adds the connected setup stores it in the order
    /// its pins were numbered in: left to right, with no profile on
    /// those screens.
    @Test("a new set stores the live order")
    func newSetStoresTheLiveOrder() throws {
        let core = makeCore()
        connect(core, ["B:100x100", "A:100x100"])
        core.state.workspaces.ensureSpace("1")
        core.spacePins = ["1": "A:100x100"]
        try core.persistProfile(named: "Fresh", modes: nil)
        let saved = try core.profiles.read(name: "Fresh")
        #expect(
            saved.monitorSets.map(\.monitors)
                == [["B:100x100", "A:100x100"]]
        )
        #expect(saved.spaceMonitorMap == ["1": ScreenSlotKey(number: 2)!])
    }
}

/// A create on screens another profile holds claims that set, and the
/// set keeps the order its holder stored (#3647, owner 2026-11-26).
@Suite("A create keeps the held set's order (#3647)", .serialized)
@MainActor
struct NumberedPinsCreateTests {
    @Test("a new profile numbers through the held set's order")
    func createTakesTheHeldOrder() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647c-\(UUID().uuidString)")
        )
        for (index, name) in ["A", "B"].enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: name,
                    frame: CGRect(
                        x: CGFloat(index) * 100,
                        y: 0,
                        width: 100,
                        height: 100
                    )
                )
            )
        }
        let held = ["B:100x100", "A:100x100"]
        try core.profiles.write(
            Profile(
                name: "Old",
                monitorSets: [MonitorSet(monitors: held)],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        core.state.workspaces.ensureSpace("1")
        core.spacePins = ["1": "B:100x100"]
        try core.persistProfile(named: "New", modes: nil)
        let saved = try core.profiles.read(name: "New")
        #expect(saved.monitorSets.map(\.monitors) == [held])
        #expect(saved.spaceMonitorMap == ["1": ScreenSlotKey(number: 1)!])
    }
}
