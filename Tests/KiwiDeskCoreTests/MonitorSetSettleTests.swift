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
        try core.profiles.settleSharedSets()
        #expect(try core.profiles.read(name: "Alpha").isUsableDefault)
        let beta = try core.profiles.read(name: "Beta")
        #expect(beta.isDormant)
        #expect(!beta.isDefault)
        #expect(beta.monitorCount == 2)
    }

    @Test("Loading the config settles once, at the format crossing")
    func loadConfigSettlesOnce() throws {
        let core = makeCore()
        try writeLegacy(core, profile("Alpha", [desk]))
        try writeLegacy(core, profile("Beta", [desk]))
        #expect(core.profiles.hasFilesBeforeOneOwnerFormat())
        core.loadConfig()
        #expect(try core.profiles.read(name: "Beta").isDormant)
        #expect(!core.profiles.hasFilesBeforeOneOwnerFormat())

        // A duplicate hand-edited in afterwards resolves as it
        // always has: the next load does not strip it.
        try core.profiles.write(profile("Gamma", [desk]))
        core.loadConfig()
        #expect(try !core.profiles.read(name: "Gamma").isDormant)
        #expect(try !core.profiles.read(name: "Alpha").isDormant)
    }
}
