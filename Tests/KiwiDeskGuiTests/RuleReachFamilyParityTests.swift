import Foundation
import Testing

@testable import KiwiDeskCore

/// Every rule-reach family reaches the three places a Save reads
/// it (#1655's architect review): the families are the
/// `RuleReachTable` properties of `RuleReachSnapshot`, found by
/// reflection, so a sixth one reds here until `isEdited`,
/// `saveRuleReach` and `overwriteProfile`'s `writingRules: false`
/// restore all name it. Reach is a needle per site, not the
/// encode — the behaviour suites per family hold that.
@Suite("Rule reach family parity")
@MainActor
struct RuleReachFamilyParityTests {
    /// Each family → the `Profile` field a stored-profile Save
    /// keeps as stored, or nil with the reason it keeps none.
    private static let profileField: [String: String?] = [
        "appRules": "appRules",
        "floatRules": "floatRules",
        "scrollGestures": "scrollGesture",
        "spaceHistory": "spaceHistory",
        // The shortcut override is always the Save's own diff
        // (`overwriteProfile`'s docstring), never kept as stored.
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
