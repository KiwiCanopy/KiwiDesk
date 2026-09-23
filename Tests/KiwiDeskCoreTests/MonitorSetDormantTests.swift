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

/// A profile left with no screen setup is DORMANT (#1530): never
/// auto-matched, never the count's default, and back on its next
/// load or save. Split from `MonitorSetClaimTests` at the §2.1
/// ceiling.
@Suite("A profile without a set is dormant (#1530)", .serialized)
@MainActor
struct MonitorSetDormantTests {
    @Test("A dormant profile is never auto-matched")
    func dormantNeverMatched() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        try core.persistProfile(named: "Home", modes: nil)
        // "Work" is dormant; an unknown one-screen set falls to
        // the count default, which must be the live "Home".
        let match = core.profiles.match(
            fingerprints: ["Q:100x100"]
        )
        #expect(
            match
                == .countDefault(
                    try core.profiles.read(name: "Home")
                )
        )
    }

    /// A hand-written dormant default: `claim` never leaves one, so
    /// only a file can reach the matching skip this holds.
    @Test("A dormant default is never the count's fallback")
    func dormantDefaultNeverMatched() throws {
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
        #expect(try core.profiles.read(name: "Resting").isDormant)
        #expect(
            core.profiles.match(fingerprints: ["Q:100x100"]) == .none
        )
        #expect(core.profiles.defaultProfile(count: 1) == nil)
    }

    @Test("A default left dormant hands its flag to the claimant")
    func defaultMovesToClaimant() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        #expect(try core.profiles.read(name: "Work").isDefault)
        try core.persistProfile(named: "Home", modes: nil)
        #expect(try !core.profiles.read(name: "Work").isDefault)
        #expect(core.profiles.defaultProfile(count: 1)?.name == "Home")
    }

    @Test("A dormant profile re-claims a set on its next load")
    func dormantReclaims() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        try core.persistProfile(named: "Home", modes: nil)
        let released = try core.loadProfile(named: "Work")
        #expect(released == ["Home"])
        #expect(try !core.profiles.read(name: "Work").isDormant)
        #expect(try core.profiles.read(name: "Home").isDormant)
    }

    @Test("A copy starts dormant with its source's count")
    func copyIsDormant() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        let name = try core.copyProfile(
            named: "Work",
            to: "Copy",
            with: core.guiConfigSeed()
        )
        let copy = try core.profiles.read(name: name)
        #expect(copy.isDormant)
        #expect(copy.monitorCount == 1)
        #expect(try !core.profiles.read(name: "Work").isDormant)
    }
}
