import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// One draft, one identity, and no half a Save (#1393, architect
/// round 2): the page is pinned per settled target; a profile
/// loaded under a clean page repins it and under a dirty one
/// refuses the Save; a failed rule write never lets the base half
/// land alone, and a landed one is adopted as clean.
@Suite("Rule reach identity and failure (#1393)", .serialized)
@MainActor
struct RuleReachIdentityTests {
    /// gui.json opens Mail in Space 1; Work is loaded, Home stored.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        config.appRules = ["mail": SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1"), SpaceID("2")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    private func corrupt(_ model: SettingsModel, _ name: String) throws {
        let url = try model.core.profiles.fileURL(name: name)
        try Data("not json".utf8).write(to: url)
    }

    @Test("A stored target that fell back to live pins the live page")
    func fallbackPinsLive() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")
        #expect(model.reachProfile == "Home")
        try model.core.profiles.delete(name: "Home")

        model.reload()

        #expect(model.target == .live)
        #expect(model.reachProfile == "Work")
    }

    @Test("A profile loaded under a dirty draft refuses its Save")
    func pageMovedRefuses() throws {
        let model = try makeModel()
        model.config.appRules["mail"] = SpaceID("2")
        _ = try model.core.loadProfile(named: "Home")
        model.refreshProfiles()

        model.updateActiveProfile()

        #expect(model.profileWarning != nil)
        #expect(
            model.core.guiConfigStore.load()?.appRules["mail"]
                == SpaceID("1")
        )
        #expect(try model.core.profiles.read(name: "Work").appRules == nil)
    }

    @Test("A clean live page repins when another profile loads")
    func cleanPageRepins() throws {
        let model = try makeModel()
        #expect(!model.isDirty)
        _ = try model.core.loadProfile(named: "Home")

        model.refreshProfiles()

        #expect(model.reachProfile == "Home")
        #expect(!model.pageMoved)
    }

    @Test("A stored Save whose tiling write fails adopts the rules")
    func storedTilingFailureAdoptsRules() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")
        // A shared-value edit reaches only the base, so the rule
        // half lands; Home's own file then refuses the tiling read.
        model.config.appRules["mail"] = SpaceID("2")
        model.config.spaces = [SpaceID("1")]
        try corrupt(model, "Home")

        model.saveEditedProfile()

        #expect(
            model.core.guiConfigStore.load()?.appRules["mail"]
                == SpaceID("2")
        )
        #expect(model.cleanConfig.appRules["mail"] == SpaceID("2"))
        #expect(model.reachDiffRows().isEmpty)
        // The tiling edit did not land, so it stays unsaved.
        #expect(model.isDirty)
    }

    @Test("A page drawn with no profile counts as moved by a load")
    func unnamedPageMoves() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        #expect(model.reachProfile == nil)
        model.config.appRules["mail"] = SpaceID("2")
        _ = try core.loadProfile(named: "Home")
        model.refreshProfiles()

        #expect(model.pageMoved)
        model.saveGlobalsWhilePaused()
        #expect(model.profileWarning != nil)
        #expect(core.guiConfigStore.load()?.appRules["mail"] == nil)
    }

    @Test("A stored Save with no checklist adopts nothing on failure")
    func noChecklistAdoptsNothing() throws {
        let core = makeTestCore()
        // No gui.json: the base is not GUI-owned, so no checklist.
        try core.profiles.save(profile("Work"))
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        model.selectEditTarget("Home")
        #expect(model.target == .storedProfile("Home"))
        #expect(model.ruleReachStored == nil)
        model.config.appRules["notes"] = SpaceID("2")
        let url = try core.profiles.fileURL(name: "Home")
        try Data("not json".utf8).write(to: url)

        model.saveEditedProfile()

        #expect(model.profileWarning != nil)
        #expect(model.cleanConfig.appRules["notes"] == nil)
        #expect(model.isDirty)
    }

    @Test("A loaded profile gone under a dirty page refuses its Save")
    func pageGoneRefuses() throws {
        let model = try makeModel()
        model.config.appRules["mail"] = SpaceID("2")
        try model.core.profiles.delete(name: "Work")
        model.refreshProfiles()

        #expect(model.pageMoved)
        model.saveGlobalsWhilePaused()
        #expect(model.profileWarning?.contains("Work") == true)
        #expect(
            model.core.guiConfigStore.load()?.appRules["mail"]
                == SpaceID("1")
        )
    }

    @Test("An unreadable reached profile refuses the whole rule write")
    func unreadableRefusesAll() throws {
        let model = try makeModel()
        // Unticking All reaches Work and Home; Home cannot be read.
        model.setAllProfiles(.space, "mail", false)
        try corrupt(model, "Home")

        model.updateActiveProfile()

        // Nothing landed: Work's file and the base are as stored.
        #expect(try model.core.profiles.read(name: "Work").appRules == nil)
        #expect(
            model.core.guiConfigStore.load()?.appRules["mail"]
                == SpaceID("1")
        )
    }

    @Test("A failed rule write keeps the base out of the globals")
    func failedReachKeepsBase() throws {
        let model = try makeModel()
        model.setAllProfiles(.space, "mail", false)
        model.config.ignoreRules = ["com.example.ignored"]
        try corrupt(model, "Home")

        model.updateActiveProfile()

        let saved = model.core.guiConfigStore.load()
        #expect(saved?.appRules["mail"] == SpaceID("1"))
        #expect(saved?.ignoreRules == ["com.example.ignored"])
    }

    @Test("A stored Save whose rule write fails keeps the draft")
    func storedFailureKeepsDraft() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")
        model.setAllProfiles(.space, "mail", false)
        model.config.spaces = [SpaceID("1")]
        try corrupt(model, "Work")

        model.saveEditedProfile()

        #expect(model.isDirty)
        #expect(model.profileWarning != nil)
        let home = try model.core.profiles.read(name: "Home")
        #expect(home.spaces == [SpaceID("1"), SpaceID("2")])
    }

    /// The page a draft encodes against is the pin, never Core's
    /// live name: a live read is how a mid-save name change baked
    /// one profile's own rules into the shared base. A spelling
    /// scan over these four files — a fifth reach file is
    /// review's.
    @Test("the rule-reach files read no live profile name")
    func reachFilesReadThePin() throws {
        let settings = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let names = [
            "SettingsModel+RuleReach.swift",
            "SettingsModel+RuleReachEdit.swift",
            "SettingsModel+RuleReachDiff.swift",
            "RuleReachDraft.swift",
        ]
        for name in names {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: settings.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
            #expect(!source.contains("currentName"), "\(name)")
        }
    }
}
