import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Forgetting a screen setup reaches MCP as a destructive command
/// with no MCP-specific code (#3324 ▸ MCP amendment): its
/// `APIReference.destructive` entry routes it to `run_destructive`,
/// and the list read stays an ordinary command.
@Suite("MCP forgets a setup only through run_destructive (#3324)")
struct MCPForgetSetupTests {
    private static func group(of command: String) -> String? {
        APIReference.groups.first { group in
            group.entries.contains { $0.qualifiedName == command }
        }?.name
    }

    @Test("the forget is among its group's destructive names")
    func forgetIsDestructive() throws {
        let group = try #require(Self.group(of: "forget_monitor_set"))
        let destructive = MCPTools.groupEntries(group)
            .filter(APIReference.isDestructive)
            .map(\.qualifiedName)
        #expect(destructive.contains("forget_monitor_set"))
        #expect(!destructive.contains("list_monitor_sets"))
        let offered = MCPTools.offered(group: group).map(\.qualifiedName)
        #expect(!offered.contains("forget_monitor_set"))
        #expect(offered.contains("list_monitor_sets"))
    }

    @Test("plain run refuses the forget and sends nothing")
    func plainRunRefuses() throws {
        let app = MCPToolsTests.FakeApp()
        let result = try MCPToolsTests.call(
            app.tools,
            MCPTools.run,
            MCPToolsTests.command(
                "forget_monitor_set",
                [.string("A:100x100")]
            )
        )
        #expect(result["isError"] == .bool(true))
        #expect(MCPToolsTests.text(result).contains("run_destructive"))
        #expect(app.sent.isEmpty)
        let routed = try MCPToolsTests.call(
            app.tools,
            MCPTools.runDestructive,
            MCPToolsTests.command(
                "forget_monitor_set",
                [.string("A:100x100")]
            )
        )
        #expect(routed["isError"] != .bool(true))
        #expect(app.sent.map(\.command) == ["forget_monitor_set"])
    }
}
