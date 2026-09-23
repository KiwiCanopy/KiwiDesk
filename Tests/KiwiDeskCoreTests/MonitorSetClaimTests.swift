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
                "kiwi-claim-\(UUID().uuidString)"
            )
    )
}

/// A 100x100 screen, fingerprint `"<name>:100x100"`.
private func screen(_ id: UInt32, _ name: String) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(
            x: CGFloat(id) * 100,
            y: 0,
            width: 100,
            height: 100
        )
    )
}

/// Replaces the connected screens with `names` — the fake
/// topology every clause runs on.
@MainActor
private func connect(_ core: KiwiCore, _ names: [String]) {
    for display in core.state.workspaces.allDisplays {
        core.state.workspaces.removeDisplay(display.id)
    }
    for (index, name) in names.enumerated() {
        core.state.workspaces.upsertDisplay(
            screen(UInt32(index + 1), name)
        )
    }
}

private func fingerprints(_ names: [String]) -> [String] {
    names.map { "\($0):100x100" }.sorted()
}

/// A monitor combination belongs to one profile — the one most
/// recently stored or loaded with it (#1530).
@Suite("A monitor combination has one owner (#1530)", .serialized)
@MainActor
struct MonitorSetClaimTests {
    @Test("A save claims the set from a same-count sibling")
    func saveStripsSibling() throws {
        let core = makeCore()
        connect(core, ["A", "B"])
        try core.persistProfile(named: "Work", modes: nil)
        let released = try core.persistProfile(
            named: "Home",
            modes: nil
        )
        #expect(released == ["Work"])
        let work = try core.profiles.read(name: "Work")
        #expect(work.isDormant)
        #expect(work.monitorCount == 2)
        let home = try core.profiles.read(name: "Home")
        #expect(home.set(matching: fingerprints(["A", "B"])) != nil)
    }

    @Test("Only the claimed set leaves; the owner's others stay")
    func otherSetsStay() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        connect(core, ["C"])
        try core.persistProfile(named: "Work", modes: nil)
        try core.persistProfile(named: "Home", modes: nil)
        let work = try core.profiles.read(name: "Work")
        #expect(!work.isDormant)
        #expect(work.monitorSets.map(\.monitors) == [["A:100x100"]])
    }

    @Test("A profile of another screen count is never stripped")
    func otherCountUntouched() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Solo", modes: nil)
        connect(core, ["A", "B"])
        let released = try core.persistProfile(
            named: "Dual",
            modes: nil
        )
        #expect(released.isEmpty)
        #expect(try !core.profiles.read(name: "Solo").isDormant)
    }

    @Test("A load claims the connected set where the count fits")
    func loadClaims() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        connect(core, ["V"])
        try core.persistProfile(named: "Vision", modes: nil)
        try core.persistProfile(named: "Work", modes: nil)
        // "Work" now holds A and V; loading "Vision" on V takes V.
        let released = try core.loadProfile(named: "Vision")
        #expect(released == ["Work"])
        #expect(
            try core.profiles.read(name: "Work")
                .set(matching: ["V:100x100"]) == nil
        )
        #expect(core.profiles.currentName == "Vision")
        #expect(!core.profiles.isDirty)
    }

    @Test("A load adds an unknown combination to the profile")
    func loadAddsUnknownSet() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        connect(core, ["Z"])
        try core.loadProfile(named: "Work")
        let work = try core.profiles.read(name: "Work")
        #expect(work.set(matching: ["Z:100x100"]) != nil)
        #expect(!core.profiles.isDirty)
    }

    @Test("A load of another screen count claims nothing")
    func misfitLoadClaimsNothing() throws {
        let core = makeCore()
        connect(core, ["A", "B"])
        try core.persistProfile(named: "Dual", modes: nil)
        connect(core, ["A"])
        // A same-count sibling holding the connected set: a wrongful
        // strip has something to take.
        try core.persistProfile(named: "Solo", modes: nil)
        let released = try core.loadProfile(named: "Dual")
        #expect(released.isEmpty)
        #expect(try !core.profiles.read(name: "Solo").isDormant)
        #expect(
            try core.profiles.read(name: "Dual").monitorSets.count
                == 1
        )
        #expect(core.profiles.isDirty)
    }

    /// The claimant sorts SECOND, so an unstripped tie would hand
    /// the match to "Alpha" alphabetically.
    @Test("The claimed set wins the next monitor change")
    func loadSticksAtMonitorChange() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Beta", modes: nil)
        try core.persistProfile(named: "Alpha", modes: nil)
        try core.loadProfile(named: "Beta")
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "Beta")
    }

    @Test("Boot matching never strips a doubly-held set")
    func bootNeverStrips() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Alpha", modes: nil)
        var twin = try core.profiles.read(name: "Alpha")
        twin.name = "Beta"
        twin.isDefault = false
        try core.profiles.write(twin)
        core.handleMonitorChange()
        #expect(try !core.profiles.read(name: "Alpha").isDormant)
        #expect(try !core.profiles.read(name: "Beta").isDormant)
    }

    @Test("The Profiles page's pick moves a stored set")
    func pickClaimsStoredSet() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        connect(core, ["B"])
        try core.persistProfile(named: "Home", modes: nil)
        #expect(
            core.claimableMonitorSets(for: "Home")
                == [["A:100x100"], ["B:100x100"]]
        )
        let released = try core.claimMonitorSet(
            ["A:100x100"],
            for: "Home"
        )
        #expect(released == ["Work"])
        #expect(try core.profiles.read(name: "Work").isDormant)
        #expect(throws: (any Error).self) {
            try core.claimMonitorSet(
                ["A:100x100", "B:100x100"],
                for: "Home"
            )
        }
    }

    @Test("save_profile names what it took, and why")
    func commandPayload() throws {
        let core = makeCore()
        connect(core, ["A"])
        let first = core.execute(
            "save_profile",
            args: [.string("Work")]
        )
        #expect(first == .ok())
        let second = core.execute(
            "save_profile",
            args: [.string("Home")]
        )
        guard case .object(let payload) = second.data else {
            Issue.record("no payload: \(second)")
            return
        }
        #expect(payload["takenFrom"] == .array([.string("Work")]))
        #expect(payload["reason"]?.stringValue?.isEmpty == false)
        let load = core.execute(
            "load_profile",
            args: [.string("Work")]
        )
        guard case .object(let back) = load.data else {
            Issue.record("no payload: \(load)")
            return
        }
        #expect(back["takenFrom"] == .array([.string("Home")]))
    }
}
