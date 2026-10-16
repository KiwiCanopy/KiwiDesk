import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Claude Code plugin's source under `plugins/` (#2258 ▸
/// Ruling 3), the folder the release copies to kiwidesk-claude: it
/// starts the server under its own name and arguments, its skill
/// teaches every tool the server offers, and the version is the
/// release sync's to stamp.
@Suite("Claude Code plugin source")
struct ClaudePluginSourceTests {
    static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("plugins")

    static func json(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: root.appendingPathComponent(path))
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    static func text(_ path: String) throws -> String {
        try String(
            contentsOf: root.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    @Test("the marketplace lists the plugin folder")
    func marketplaceLists() throws {
        let market = try Self.json(".claude-plugin/marketplace.json")
        let plugins = try #require(market["plugins"] as? [[String: Any]])
        #expect(plugins.count == 1)
        let source = try #require(plugins.first?["source"] as? String)
        let folder = Self.root.appendingPathComponent(source)
        #expect(
            FileManager.default.fileExists(
                atPath: folder.appendingPathComponent(
                    ".claude-plugin/plugin.json"
                ).path
            )
        )
    }

    @Test("the server starts under its name, through the launcher")
    func serverEntry() throws {
        let config = try Self.json("kiwidesk/.mcp.json")
        let servers = try #require(
            config["mcpServers"] as? [String: Any]
        )
        #expect(Array(servers.keys) == [MCPInvocation.serverName])
        let server = try #require(
            servers[MCPInvocation.serverName] as? [String: Any]
        )
        let command = try #require(server["command"] as? String)
        let prefix = "${CLAUDE_PLUGIN_ROOT}/"
        #expect(command.hasPrefix(prefix))
        let launcher = Self.root.appendingPathComponent("kiwidesk")
            .appendingPathComponent(String(command.dropFirst(prefix.count)))
        #expect(FileManager.default.isExecutableFile(atPath: launcher.path))
        let script = try String(contentsOf: launcher, encoding: .utf8)
        let args = MCPInvocation.args.joined(separator: " ")
        #expect(script.contains("exec \"$KIWIDESK\" \(args)\n"))
    }

    @Test("the skill teaches every tool the server offers")
    @MainActor func skillNamesEveryTool() throws {
        let skill = try Self.text("kiwidesk/skills/drive/SKILL.md")
        guard case .array(let tools) = MCPTools().definitions else {
            Issue.record("no tools")
            return
        }
        #expect(!tools.isEmpty)
        for tool in tools {
            guard case .object(let fields) = tool else {
                Issue.record("a tool is not an object")
                continue
            }
            let name = try #require(fields["name"]?.stringValue)
            #expect(skill.contains("`\(name)`"), "\(name)")
        }
    }

    @Test("the version is left to the release sync")
    func noVersionInSource() throws {
        let plugin = try Self.json("kiwidesk/.claude-plugin/plugin.json")
        #expect(plugin["name"] as? String == MCPInvocation.serverName)
        #expect(plugin["version"] == nil)
    }
}
