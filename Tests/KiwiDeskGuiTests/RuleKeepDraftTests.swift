import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

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
