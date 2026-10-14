import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The keep half of `kiwidesk mcp` for app rules (#1685 ▸ Ruling
/// 6c): a rule change is told as going to the shared rules, and a
/// keep names every profile it reached.
@Suite("MCP keep rules")
struct MCPKeepRulesTests {
    @Test("a shared-rule keep is told and names the profiles reached")
    func sharedRulesAreTold() throws {
        let app = MCPKeepTests.FakeApp()
        app.touched["app_rule.set_space"] = [
            MCPKeepTests.leaf("/app_rules/com.x", .sharedRules)
        ]
        let set = try MCPKeepTests.run(app, "app_rule.set_space")
        #expect(MCPKeepTests.text(set).contains("shared rules"))
        app.keepAnswer = .object([
            "profile": .string("Work"),
            "kept": .array([
                .object([
                    "id": .string("/app_rules/com.x"),
                    "owner": .string("shared_rules"),
                ])
            ]),
            "rule_profiles": .array([.string("Home"), .string("Work")]),
        ])
        let kept = try MCPKeepTests.call(app, MCPTools.keep)
        #expect(MCPKeepTests.text(kept).contains("apply in: Home, Work"))
    }
}
