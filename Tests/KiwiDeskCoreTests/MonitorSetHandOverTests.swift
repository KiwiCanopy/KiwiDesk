import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-handover-\(UUID().uuidString)"
            )
    )
}

/// Replaces the connected screens with 100x100 ones named `names`.
@MainActor
private func connect(_ core: KiwiCore, _ names: [String]) {
    for display in core.state.workspaces.allDisplays {
        core.state.workspaces.removeDisplay(display.id)
    }
    for (index, name) in names.enumerated() {
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
}

/// What travels with a monitor set when it changes hands (#1530):
/// the pins, the live profile's #36 fit, and the default flag's
/// writers.
@Suite("A monitor set changing hands (#1530)", .serialized)
@MainActor
struct MonitorSetHandOverTests {
    private let pair = ["A:100x100", "B:100x100"]

    /// A two-screen profile "Work" whose Space 2 is pinned to B.
    private func pinnedWork(_ core: KiwiCore) throws {
        connect(core, ["A", "B"])
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.spacePins = ["2": "B:100x100"]
        try core.persistProfile(named: "Work", modes: nil)
    }

    @Test("A load that takes a set brings its owner's pins")
    func loadCarriesPins() throws {
        let core = makeCore()
        try pinnedWork(core)
        try core.persistProfile(named: "Home", modes: nil)
        // Home holds the pair now, with the pins it saved; a load
        // of Work takes it back and must not arrive unpinned.
        try core.loadProfile(named: "Work")
        let work = try core.profiles.read(name: "Work")
        #expect(
            work.set(matching: pair)?.spaceMonitorMap
                == ["2": "B:100x100"]
        )
    }

    @Test("A pick carries only the pins of Spaces it declares")
    func pickFiltersPins() throws {
        let core = makeCore()
        try pinnedWork(core)
        try core.profiles.write(
            Profile(
                name: "Solo",
                monitorSets: [],
                monitorCount: 2,
                spaces: ["1"],
                spaceModes: ["1": .bsp],
                settings: TilingSettings()
            )
        )
        try core.claimMonitorSet(pair, for: "Solo")
        let solo = try core.profiles.read(name: "Solo")
        #expect(solo.set(matching: pair)?.spaceMonitorMap == [:])
        try core.claimMonitorSet(pair, for: "Work")
        #expect(
            try core.profiles.read(name: "Work")
                .set(matching: pair)?.spaceMonitorMap == [:]
        )
    }

    @Test("Picking the connected set away leaves the live one dirty")
    func pickAwayDirtiesLive() throws {
        let core = makeCore()
        try pinnedWork(core)
        try core.persistProfile(named: "Home", modes: nil)
        try core.loadProfile(named: "Work")
        #expect(!core.profiles.isDirty)
        try core.claimMonitorSet(pair, for: "Home")
        #expect(core.profiles.currentName == "Work")
        #expect(core.profiles.isDirty)
        // Picked back onto the live profile, it fits again and its
        // pins are live at once — its next save cannot drop them.
        core.spacePins = [:]
        try core.claimMonitorSet(pair, for: "Work")
        #expect(!core.profiles.isDirty)
        #expect(core.spacePins == ["2": "B:100x100"])
    }

    @Test("A pick of a disconnected set leaves the live fit alone")
    func disconnectedPickKeepsFit() throws {
        let core = makeCore()
        connect(core, ["B"])
        try core.persistProfile(named: "Home", modes: nil)
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        try core.loadProfile(named: "Work")
        // Taking Home's B for Work fits nothing new on screen.
        core.profiles.markDirty()
        try core.claimMonitorSet(["B:100x100"], for: "Work")
        #expect(core.profiles.isDirty)
        // A is no longer connected, so taking it from the loaded
        // Work re-judges nothing either.
        core.profiles.markClean()
        connect(core, ["C"])
        try core.claimMonitorSet(["A:100x100"], for: "Home")
        #expect(!core.profiles.isDirty)
    }

    /// The owner order runs against the monitor order, so a sort
    /// by monitors cannot pass for a sort by owner.
    @Test("The + list: connected first, then by owner")
    func claimableOrder() throws {
        let core = makeCore()
        connect(core, ["B"])
        try core.persistProfile(named: "Alpha", modes: nil)
        connect(core, ["A"])
        try core.persistProfile(named: "Zed", modes: nil)
        connect(core, ["C"])
        try core.persistProfile(named: "Home", modes: nil)
        connect(core, ["D"])
        try core.persistProfile(named: "Mid", modes: nil)
        let choices = core.claimableMonitorSets(for: "Home")
        #expect(choices.map(\.owner) == ["Mid", "Alpha", "Zed"])
        #expect(choices.map(\.isConnected) == [true, false, false])
    }

    @Test("A dormant profile cannot be made the default")
    func setDefaultRefusesDormant() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        try core.persistProfile(named: "Home", modes: nil)
        #expect(try core.profiles.read(name: "Work").isDormant)
        #expect(throws: ProfileError.self) {
            try core.profiles.setDefault(name: "Work")
        }
        #expect(core.profiles.defaultProfile(count: 1)?.name == "Home")
    }

    @Test("A deleted default's heir is never a dormant profile")
    func heirSkipsDormant() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Alpha", modes: nil)
        try core.persistProfile(named: "Beta", modes: nil)
        connect(core, ["C"])
        try core.persistProfile(named: "Charlie", modes: nil)
        // Alpha is dormant; Beta holds A and is the default.
        try core.profiles.delete(name: "Beta")
        #expect(try !core.profiles.read(name: "Alpha").isDefault)
        #expect(
            core.profiles.defaultProfile(count: 1)?.name == "Charlie"
        )
    }

    /// A dormant default left by a hand edit loses its flag when
    /// another profile becomes that count's default, so the count
    /// never shows two.
    @Test("A new default clears a dormant profile's stale flag")
    func newDefaultClearsDormantFlag() throws {
        let core = makeCore()
        try core.profiles.write(
            Profile(
                name: "Resting",
                monitorSets: [],
                monitorCount: 1,
                isDefault: true,
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        #expect(try core.profiles.read(name: "Work").isDefault)
        #expect(try !core.profiles.read(name: "Resting").isDefault)
    }

    /// A save never takes a set another profile owns — the live
    /// profile is on those screens through a binding or a set
    /// moved away by hand (owner, 2026-09-23). A load still does.
    @Test("A save leaves a set another profile owns with it")
    func saveLeavesOwnedSet() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Starter", modes: nil)
        connect(core, ["V"])
        try core.persistProfile(named: "Vision", modes: nil)
        // Starter lands on V the way a binding puts it there.
        core.apply(
            profile: try core.profiles.read(name: "Starter"),
            cause: .event
        )
        let released = try core.persistProfile(
            named: "Starter",
            modes: nil
        )
        #expect(released.isEmpty)
        #expect(
            try core.profiles.read(name: "Starter")
                .set(matching: ["V:100x100"]) == nil
        )
        #expect(try !core.profiles.read(name: "Vision").isDormant)
        // A save of a set no one owns still adds it.
        connect(core, ["N"])
        try core.persistProfile(named: "Starter", modes: nil)
        #expect(
            try core.profiles.read(name: "Starter")
                .set(matching: ["N:100x100"]) != nil
        )
    }
}
