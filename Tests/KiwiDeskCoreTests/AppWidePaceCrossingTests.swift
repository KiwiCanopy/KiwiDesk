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
        // Captured from the migrated bytes: the 0 is already the
        // default length, never the floor.
        #expect(core.appWideLedger.owedPace?["Work"]?.revealDuration == 300)
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
        // The profile not applied migrated before the strip, so its
        // 0 crossed to the switch off rather than leaving with it.
        let calm = try core.profiles.read(name: "Calm")
        #expect(!calm.settings.animations.onReveal)
    }

    @Test("the strip is surgical and leaves valid JSON")
    func stripIsSurgical() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, format: 38, in: core)
        // A spacing the re-encoding fallback would not reproduce.
        let url = try core.profiles.fileURL(name: "Work")
        let spaced = try text("Work", core).replacingOccurrences(
            of: "\"on_relayout\" : true",
            with: "\"on_relayout\" :  true"
        )
        try spaced.write(to: url, atomically: true, encoding: .utf8)
        core.prepareAppWide()
        load("Work", core)
        let after = try text("Work", core)
        #expect(after.contains("\"on_relayout\" :  true"))
        #expect(!after.contains("duration\""))
        #expect(
            after.range(of: #",\s*[}\]]"#, options: .regularExpression)
                == nil
        )
        let removed = spaced.components(separatedBy: "\n")
            .filter { !$0.isEmpty && !after.contains($0) }
        // The four lengths, and the member before the last cut losing
        // the comma that no longer separates anything.
        #expect(
            removed.filter { $0.contains("duration\"") }.count == 4,
            "\(removed)"
        )
        #expect(
            removed.allSatisfy {
                $0.contains("duration\"") || $0.contains("on_window_swap")
            },
            "\(removed)"
        )
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
        #expect(
            core.appWide.animationDurationMS
                == AnimationPacePreset.shipped.window
        )
    }

    @Test("a failed adoption write strips nothing")
    func failedWriteKeepsTheProfiles() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, in: core)
        core.prepareAppWide()
        try Data("{ not json".utf8).write(to: core.guiConfigStore.url)
        load("Work", core)
        #expect(try text("Work", core).contains("\"duration\""))
    }

    @Test("a Lua-owned config owes nothing and runs at the defaults")
    func luaOwnedOwesNothing() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, in: core)
        core.prepareAppWide()
        #expect(core.appWideLedger.owedPace != nil)
        try "KiwiDesk.bind(\"cmd+h\", function() end)\n".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        #expect(!core.isGuiManaged)
        core.prepareAppWide()
        #expect(core.appWideLedger.owedPace == nil)
        load("Work", core)
        #expect(
            core.appWide.animationDurationMS
                == AnimationPacePreset.shipped.window
        )
        #expect(try text("Work", core).contains("\"duration\""))
    }

    @Test("a capture follows its file's rename and delete")
    func captureFollowsTheFile() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, in: core)
        try saveLegacy("Calm", duration: 700, in: core)
        core.prepareAppWide()
        core.renameAppWideCapture("Calm", to: "Quiet")
        #expect(core.appWideLedger.owedPace?["Quiet"]?.duration == 700)
        #expect(core.appWideLedger.owedPace?["Calm"] == nil)
        core.forgetAppWideCapture(of: "Work")
        #expect(core.appWideLedger.owedPace?["Work"] == nil)
    }

    @Test("a backup's inline lengths cross for that bundle alone")
    func backupPairsByBundle() throws {
        let core = try makeCrossedCore()
        try saveLegacy("Work", duration: 400, in: core)
        let data = try Data(contentsOf: core.profiles.fileURL(name: "Work"))
        var root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        root["format"] = 37
        var wide = AppWideSettings()
        wide.animationPaceStored = false
        var config = GuiConfig()
        config.appWide = wide
        let bundle = SetupBundle(
            writtenBy: "test",
            config: config,
            profiles: [profile(named: "Work")],
            palettes: []
        )
        var bundleRoot = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(bundle)
            ) as? [String: Any]
        )
        bundleRoot["profiles"] = [root]
        bundleRoot["format"] = 46
        let bytes = try JSONSerialization.data(withJSONObject: bundleRoot)
        core.noteBackupAppWide(bundle, bytes: bytes)
        core.takeRestoredAppWide(from: bundle)
        #expect(core.appWideLedger.owedPace?["Work"]?.duration == 400)
        core.noteBackupAppWide(bundle, bytes: bytes)
        let other = SetupBundle(
            writtenBy: "other",
            config: config,
            profiles: [profile(named: "Work")],
            palettes: []
        )
        core.takeRestoredAppWide(from: other)
        #expect(core.appWideLedger.owedPace?["Work"] == nil)
    }
}
