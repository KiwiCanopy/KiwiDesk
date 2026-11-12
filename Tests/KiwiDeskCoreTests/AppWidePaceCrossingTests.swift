import Foundation
import Testing

@testable import KiwiDeskCore

/// The animation lengths' crossing (#3237), a crossing of its own
/// beside #1741's: owed while `gui.json` lacks the `animations`
/// group, captured from the profiles' MIGRATED bytes before any
/// rewrite, adopted from the live profile at its first apply or a
/// row write, then stripped from every profile file; a Lua-owned
/// config owes nothing, and a `gui.json` write while owed keeps the
/// signal.
@Suite("App-wide pace crossing (#3237)", .serialized)
@MainActor
struct AppWidePaceCrossingTests {
    private func directory() -> URL {
        testTemporaryDirectory
            .appendingPathComponent("kiwi-pace-\(UUID().uuidString)")
    }

    /// A core whose `gui.json` crossed #1741 but has no group yet.
    private func makeCrossedCore() throws -> KiwiCore {
        let core = makeTestCore(configDirectory: directory())
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.refusalSound = true
        wide.animationPaceStored = false
        config.appWide = wide
        try core.guiConfigStore.save(config)
        return core
    }

    private func profile(named name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    /// Saves `name` with an older build's lengths in its file, at
    /// `format`, the reveal stored as a #3236-era 0.
    private func saveLegacy(
        _ name: String,
        duration: Int,
        format: Int = 36,
        in core: KiwiCore
    ) throws {
        try core.profiles.save(profile(named: name))
        let url = try core.profiles.fileURL(name: name)
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        var settings = try #require(root["settings"] as? [String: Any])
        var animations = try #require(
            settings["animations"] as? [String: Any]
        )
        animations["duration"] = duration
        animations["scroll_duration"] = 200
        animations["reveal_duration"] = 0
        animations["expand_duration"] = 1000
        animations["on_reveal"] = nil
        settings["animations"] = animations
        root["settings"] = settings
        root["format"] = format
        try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: url)
    }

    private func load(_ name: String, _ core: KiwiCore) {
        #expect(
            core.execute("load_profile", args: [.string(name)])
                .isSuccess
        )
    }

    private func text(_ name: String, _ core: KiwiCore) throws -> String {
        try String(
            contentsOf: core.profiles.fileURL(name: name),
            encoding: .utf8
        )
    }

    private func guiText(_ core: KiwiCore) throws -> String {
        try String(contentsOf: core.guiConfigStore.url, encoding: .utf8)
    }

    @Test("the live profile's lengths are adopted and stripped")
    func adoptionStampsAndStrips() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, in: core)
        try saveLegacy("Calm", duration: 700, in: core)
        core.prepareAppWide()
        #expect(core.appWideLedger.owedPace?.count == 2)
        load("Work", core)
        #expect(core.appWideLedger.owedPace == nil)
        #expect(core.appWide.animationDurationMS == 400)
        #expect(core.appWide.animationScrollDurationMS == 200)
        // The stored 0 crossed to the switch off, not to the floor.
        #expect(core.appWide.animationRevealDurationMS == 300)
        #expect(core.appWide.animationExpandDurationMS == 1000)
        #expect(core.tiler.animation.durationMS == 400)
        // #1741's values are kept: this crossing owes only pace.
        #expect(core.appWide.refusalSound)
        let stored = try #require(core.guiConfigStore.load()?.appWide)
        #expect(stored.animationPaceStored)
        #expect(stored.animationDurationMS == 400)
        for name in ["Work", "Calm"] {
            let body = try text(name, core)
            #expect(!body.contains("\"duration\""), "\(name)")
            #expect(!body.contains("\"scroll_duration\""), "\(name)")
        }
    }

    @Test("the strip is surgical")
    func stripIsSurgical() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, format: 38, in: core)
        let before = try text("Work", core)
        core.prepareAppWide()
        load("Work", core)
        let after = try text("Work", core)
        let removed = before.components(separatedBy: "\n")
            .filter { !after.contains($0) }
        #expect(removed.count == 4, "\(removed)")
        #expect(removed.allSatisfy { $0.contains("duration\"") })
    }

    @Test("a gui.json write while owed keeps the signal")
    func writeWhileOwedKeepsTheSignal() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, in: core)
        core.prepareAppWide()
        try core.guiConfigStore.save(#require(core.guiConfigStore.load()))
        #expect(!(try guiText(core)).contains("\"animations\""))
    }

    @Test("a verb while owed changes the session alone")
    func verbNeverPersists() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, in: core)
        core.prepareAppWide()
        core.execute("animations.set_duration", args: [.number(900)])
        #expect(core.appWide.animationDurationMS == 900)
        #expect(core.appWideLedger.owedPace != nil)
        #expect(!(try guiText(core)).contains("\"animations\""))
    }

    @Test("a row write while owed ends the crossing on the live profile")
    func rowWhileOwedEndsTheCrossing() throws {
        let core = try makeCrossedCore()
        // A save adopts "Work", so it is the live profile.
        try saveLegacy("Work", duration: 400, in: core)
        #expect(core.profiles.currentName == "Work")
        core.prepareAppWide()
        core.setAppWide(persisting: true) { $0.refusalSound = false }
        #expect(core.appWideLedger.owedPace == nil)
        #expect(core.appWide.animationDurationMS == 400)
        #expect(!(try text("Work", core)).contains("\"duration\""))
    }

    @Test("a stored group owes nothing")
    func storedGroupOwesNothing() throws {
        let core = makeTestCore(configDirectory: directory())
        var config = GuiConfig()
        config.appWide = AppWideSettings()
        try core.guiConfigStore.save(config)
        try saveLegacy("Work", duration: 400, in: core)
        core.prepareAppWide()
        #expect(core.appWideLedger.owedPace == nil)
        load("Work", core)
        #expect(core.appWide.animationDurationMS == 150)
    }
}
