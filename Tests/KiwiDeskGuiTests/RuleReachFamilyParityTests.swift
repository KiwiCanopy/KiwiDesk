import Foundation
import Testing

@testable import KiwiDeskCore

/// Every rule-reach family reaches the three places a Save reads
/// it (#1655's architect review) and the one place a profile apply
/// resolves it: the families are the `RuleReachTable` properties
/// of `RuleReachSnapshot`, found by reflection, so a new one reds
/// here until `isEdited`, `saveRuleReach`, `overwriteProfile`'s
/// `writingRules: false` restore and `applyBehaviorOverrides` all
/// name it. Reach is a needle per site, not the encode — the
/// behaviour suites per family hold that.
@Suite("Rule reach family parity")
@MainActor
struct RuleReachFamilyParityTests {
    /// Each family → its `Profile` field, which a stored-profile
    /// Save keeps as stored and the apply helper resolves, or nil
    /// with the reason it does neither.
    private static let profileField: [String: String?] = [
        "appRules": "appRules",
        "floatRules": "floatRules",
        "scrollGestures": "scrollGesture",
        "spaceHistory": "spaceHistory",
        "modeCycle": "modeCycle",
        "tileRules": "tileRules",
        "floatAutomatically": "floatAutomatically",
        // The shortcut override is always the Save's own diff
        // (`overwriteProfile`'s docstring), never kept as stored,
        // and each apply caller registers it with its own VM.
        "keyLayers": nil,
    ]

    private func families() throws -> [String] {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        let snapshot = try #require(core.ruleReachSnapshot())
        return Mirror(reflecting: snapshot).children.compactMap {
            child in
            String(describing: type(of: child.value))
                .hasPrefix("RuleReachTable") ? child.label : nil
        }
    }

    private func source(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Profiles")
            .appendingPathComponent(file)
        return try SourceScan.strippedSource(at: url)
    }

    /// The body of `WindowRuleOverrides.init(_ profile:)`.
    private func windowRuleOverridesInit() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/App")
            .appendingPathComponent("KiwiCore+StructuredRules.swift")
        let text = try SourceScan.strippedSource(at: url)
        let start = try #require(
            text.range(of: "init(_ profile: Profile?) {")
        )
        let end = try #require(
            text.range(
                of: "\n    }\n",
                range: start.upperBound..<text.endIndex
            )
        )
        return String(text[start.upperBound..<end.lowerBound])
    }

    @Test("every family is mapped, and found")
    func everyFamilyIsMapped() throws {
        let found = try families()
        #expect(found.count >= 5, "reflection found \(found)")
        #expect(Set(found) == Set(Self.profileField.keys))
    }

    @Test("isEdited reads every family both ways")
    func isEditedReadsEveryFamily() throws {
        let text = try source("KiwiCore+RuleReach.swift")
        let start = try #require(
            text.range(of: "public var isEdited: Bool {")
        )
        let end = try #require(
            text.range(
                of: "\n    }\n",
                range: start.upperBound..<text.endIndex
            )
        )
        let body = String(text[start.upperBound..<end.lowerBound])
        for family in try families() {
            #expect(
                body.contains("\(family).baseTouched"),
                "\(family) base edit never marks the Save"
            )
            #expect(
                body.contains("\(family).touched"),
                "\(family) profile edit never marks the Save"
            )
        }
    }

    @Test("saveRuleReach writes every family")
    func saveWritesEveryFamily() throws {
        let body = try SourceScan.functionBody(
            of: "saveRuleReach",
            in: "KiwiCore+RuleReach.swift",
            under: "Profiles"
        )
        for family in try families() {
            #expect(
                body.contains("snapshot.\(family)"),
                "saveRuleReach never reads \(family)"
            )
        }
    }

    @Test("every family's override is applied through the one helper")
    func applyResolvesEveryFamily() throws {
        let helper = try SourceScan.functionBody(
            of: "applyBehaviorOverrides",
            in: "KiwiCore+StructuredRules.swift",
            under: "App"
        )
        // The window-rule families resolve through the one
        // `WindowRuleOverrides(profile)` reading, so its init joins
        // the helper's body — only while the helper calls it.
        #expect(helper.contains("WindowRuleOverrides(profile)"))
        let rules = try windowRuleOverridesInit()
        let body = helper + rules
        for family in try families() {
            guard let field = Self.profileField[family] ?? nil else {
                continue
            }
            #expect(
                body.contains("profile?.\(field)"),
                "\(family) never resolves on a profile apply"
            )
        }
    }

    @Test("a stored-profile Save keeps every rule family as stored")
    func overwriteKeepsEveryFamily() throws {
        let body = try SourceScan.functionBody(
            of: "overwriteProfile",
            in: "KiwiCore+ProfileEdit.swift",
            under: "Profiles"
        )
        for family in try families() {
            guard let field = Self.profileField[family] ?? nil else {
                continue
            }
            #expect(
                body.contains("existing.\(field) = stored.\(field)"),
                "\(family) is written twice on a stored Save"
            )
        }
    }
}
