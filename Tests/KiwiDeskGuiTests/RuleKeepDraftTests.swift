import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// An AI app's rule keep reaches an open Settings draft (#1685 ▸
/// Ruling 6c): a dirty live draft takes each rule the keep changed
/// on both sides of its diff, so its next Save neither writes the
/// old rule back nor counts the keep as the user's edit.
@Suite("Rule keep reaches the draft")
struct RuleKeepDraftTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("only the rules the keep changed move, the draft's own stay")
    @MainActor func keptRulesMoveOnly() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-rulekeep-\(UUID().uuidString)")
        )
        var base = GuiConfig()
        base.appRules = ["com.a": "1", "com.b": "4", "com.k": "1"]
        base.floatRules = ["com.f", "com.n"]
        base.floatAutomatically = false
        try core.guiConfigStore.save(base)
        let stored = try #require(core.ruleReachSnapshot())
        var old = GuiConfig()
        old.appRules = ["com.a": "1", "com.b": "2"]
        old.floatRules = ["com.f", "com.g"]
        old.floatAutomatically = true
        var draft = old
        draft.appRules["com.d"] = "3"
        draft.floatRules.append("com.h")
        SettingsModel.takeKeptRules(
            stored,
            page: "Work",
            over: old,
            into: &draft
        )
        #expect(
            draft.appRules
                == ["com.a": "1", "com.b": "4", "com.k": "1", "com.d": "3"]
        )
        #expect(Set(draft.floatRules) == ["com.f", "com.h", "com.n"])
        #expect(draft.floatAutomatically == false)
        var clean = old
        SettingsModel.takeKeptRules(
            stored,
            page: "Work",
            over: old,
            into: &clean
        )
        #expect(clean.appRules == base.appRules)
        #expect(Set(clean.floatRules) == Set(base.floatRules))
    }

    /// A dirty draft of a STORED profile's page reads the shared
    /// base too, so a shared keep it did not take would be encoded
    /// as the draft removing the rule — and its Save would delete
    /// it from the base and every profile.
    @Test("a dirty stored-profile draft keeps a shared keep")
    @MainActor func storedDraftKeepsTheKeep() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        let blank = { (name: String) in
            Profile(
                name: name,
                monitorSets: [MonitorSet(monitors: [])],
                spaces: [SpaceID("1")],
                spaceModes: [:],
                settings: TilingSettings()
            )
        }
        try core.profiles.save(blank("Work"))
        try core.profiles.write(blank("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        model.target = .storedProfile("Home")
        model.reload()
        model.config.floatRules.append("com.dirty")
        #expect(model.isDirty)
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.appRules.keep("com.x", value: "1", editing: "Work")
        try core.saveRuleReach(snapshot, origin: .outside)
        model.adoptRuleKeep()
        #expect(model.config.appRules["com.x"] == "1")
        #expect(model.encodedReach?.appRules.base["com.x"] == "1")
        #expect(model.isDirty)
    }

    /// The hook, its route to the model, and the keep firing it —
    /// each deletable with the merge above still green.
    static let wirings: [(String, String, String)] = [
        (
            "self?.dashboardIfCreated?.adoptRuleKeep()",
            "Sources/KiwiDesk", "AppDelegate.swift"
        ),
        (
            "model.adoptRuleKeep()",
            "Sources/KiwiDesk/Settings", "SettingsWindowController.swift"
        ),
        (
            "onRulesKept()",
            "Sources/KiwiDeskCore/Profiles", "KiwiCore+RuleReach.swift"
        ),
    ]

    @Test("each wiring exists exactly once, in its own file")
    func wiringsAreSingular() throws {
        for (needle, tree, file) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.root.appendingPathComponent(tree)
            ).filter { $0.file.lastPathComponent == file }
            #expect(
                sites.count == 1,
                "expected one `\(needle)` in \(tree)/\(file)"
            )
        }
    }
}
