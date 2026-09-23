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
                "kiwi-settle-\(UUID().uuidString)"
            )
    )
}

private func profile(
    _ name: String,
    _ sets: [[String]],
    isDefault: Bool = false
) -> Profile {
    Profile(
        name: name,
        monitorSets: sets.map { MonitorSet(monitors: $0) },
        isDefault: isDefault,
        spaceModes: ["1": .bsp],
        settings: TilingSettings()
    )
}

/// Writes `profile` as an install before #1530 left it: the real
/// encoder's bytes, stamped with the previous format.
@MainActor
private func writeLegacy(_ core: KiwiCore, _ profile: Profile) throws {
    try core.profiles.write(profile)
    let url = try core.profiles.fileURL(name: profile.name)
    var root =
        try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any] ?? [:]
    root["format"] = ProfileManager.oneOwnerFormat - 1
    try JSONSerialization.data(withJSONObject: root)
        .write(to: url, options: .atomic)
}

/// A second core over `core`'s config directory — the next launch.
@MainActor
private func relaunch(_ core: KiwiCore) -> KiwiCore {
    makeTestCore(configDirectory: core.configDirectory)
}

/// The one-time settle for an install updating past #1530: a set
/// several profiles held stays with the one that loads it today.
@Suite("Doubly-held sets settle once, at the update (#1530)", .serialized)
@MainActor
struct MonitorSetSettleTests {
    private let desk = ["Dell:1920x1080", "LG:2560x1440"]
    private let vision = ["Vision Pro:3840x2160", "Built-in:1728x1117"]

    @Test("The profile that loads today keeps the set")
    func winnerKeepsIt() throws {
        let core = makeCore()
        try writeLegacy(core, profile("Work", [desk, vision]))
        try writeLegacy(core, profile("Travel", [vision], isDefault: true))
        let before = core.profiles.match(fingerprints: vision)
        #expect(before == .exact(try core.profiles.read(name: "Travel")))

        let lines = try core.profiles.settleSharedSets()

        #expect(lines.count == 1)
        let work = try core.profiles.read(name: "Work")
        #expect(work.set(matching: vision) == nil)
        #expect(work.set(matching: desk) != nil)
        // Nothing loads differently.
        #expect(
            core.profiles.match(fingerprints: vision)
                == .exact(try core.profiles.read(name: "Travel"))
        )
    }

    @Test("A profile left with no set goes dormant, its flag handed on")
    func loserGoesDormant() throws {
        let core = makeCore()
        try writeLegacy(core, profile("Alpha", [desk]))
        try writeLegacy(core, profile("Beta", [desk], isDefault: true))
        let lines = try core.profiles.settleSharedSets()
        #expect(try core.profiles.read(name: "Alpha").isUsableDefault)
        let beta = try core.profiles.read(name: "Beta")
        #expect(beta.isDormant)
        #expect(!beta.isDefault)
        #expect(beta.monitorCount == 2)
        // The fallback for an unknown two-screen setup moved, and
        // the log says so.
        #expect(lines.contains { $0.contains("'Alpha' is now the default") })
    }

    /// The update's launch: the files predate the manager, and a
    /// Settings refresh reads (and so stamps) them before the first
    /// config load — the settle is still owed and still runs.
    @Test("The settle is owed from launch, and runs once")
    func settlesOnceFromLaunch() throws {
        let seed = makeCore()
        try writeLegacy(seed, profile("Alpha", [desk]))
        try writeLegacy(seed, profile("Beta", [desk]))
        let core = relaunch(seed)
        #expect(core.profiles.owesSetSettle)
        _ = core.profiles.allProfiles()
        core.loadConfig()
        #expect(try core.profiles.read(name: "Beta").isDormant)
        #expect(!core.profiles.owesSetSettle)

        // A duplicate hand-edited in afterwards resolves as it
        // always has: neither the next load nor the next launch
        // strips it.
        try core.profiles.write(profile("Gamma", [desk]))
        core.loadConfig()
        let next = relaunch(core)
        #expect(!next.profiles.owesSetSettle)
        next.loadConfig()
        #expect(try !next.profiles.read(name: "Gamma").isDormant)
        #expect(try !next.profiles.read(name: "Alpha").isDormant)
    }

    @Test("A stray or broken file owes no settle")
    func strayFilesOweNothing() throws {
        let seed = makeCore()
        try seed.profiles.write(profile("Alpha", [desk]))
        let dir = try seed.profiles.fileURL(name: "Alpha")
            .deletingLastPathComponent()
        try Data(#"{"note": "not a profile"}"#.utf8)
            .write(to: dir.appendingPathComponent("stray.json"))
        try Data(#"{"name": "Broken", "format": 2}"#.utf8)
            .write(to: dir.appendingPathComponent("Broken.json"))
        #expect(!relaunch(seed).profiles.owesSetSettle)
    }

    @Test("A restored backup settles its shared sets")
    func restoreSettles() throws {
        let core = makeCore()
        try core.restoreSetup(
            from: SetupBundle(
                writtenBy: "1.4.0",
                config: nil,
                profiles: [
                    profile("Alpha", [desk]),
                    profile("Beta", [desk]),
                ],
                palettes: []
            ),
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        #expect(try !core.profiles.read(name: "Alpha").isDormant)
        #expect(try core.profiles.read(name: "Beta").isDormant)
    }
}
