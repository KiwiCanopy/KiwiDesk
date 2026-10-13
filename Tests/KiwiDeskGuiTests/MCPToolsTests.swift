import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What `kiwidesk mcp`'s tools send and refuse (#1685 ▸ Ruling 3):
/// a destructive command reaches the app only through
/// `run_destructive`, which MCP clients confirm with the user.
@Suite("MCP tools")
struct MCPToolsTests {
    /// Records what reached the app and answers from `reply`.
    final class FakeApp: @unchecked Sendable {
        var sent: [CommandRequest] = []
        var reply: (CommandRequest) -> CommandResponse = { _ in .ok() }

        var tools: MCPTools {
            var tools = MCPTools()
            tools.send = { request in
                self.sent.append(request)
                return self.reply(request)
            }
            return tools
        }
    }

    static func call(
        _ tools: MCPTools,
        _ name: String,
        _ arguments: [String: JSONValue] = [:]
    ) throws -> [String: JSONValue] {
        let result = try tools.call([
            "name": .string(name), "arguments": .object(arguments),
        ])
        guard case .object(let fields) = result else { return [:] }
        return fields
    }

    static func text(_ result: [String: JSONValue]) -> String {
        guard case .array(let items)? = result["content"],
            case .object(let first)? = items.first
        else { return "" }
        return first["text"]?.stringValue ?? ""
    }

    static func command(_ name: String, _ args: [JSONValue] = [])
        -> [String: JSONValue]
    {
        ["command": .string(name), "args": .array(args)]
    }

    @Test("run refuses a destructive command and sends nothing")
    func runRefusesDestructive() throws {
        let app = FakeApp()
        for name in APIReference.destructive.sorted() {
            let result = try Self.call(
                app.tools,
                MCPTools.run,
                Self.command(name)
            )
            #expect(result["isError"] == .bool(true), "\(name)")
            #expect(Self.text(result).contains("run_destructive"))
        }
        #expect(app.sent.isEmpty)
    }

    @Test("run_destructive sends a destructive command and only one")
    func runDestructiveRoutes() throws {
        let app = FakeApp()
        let sent = try Self.call(
            app.tools,
            MCPTools.runDestructive,
            Self.command("delete_space", [.string("9")])
        )
        #expect(sent["isError"] == .bool(false))
        #expect(app.sent.map(\.command) == ["delete_space"])
        #expect(app.sent.first?.args == [.string("9")])
        let refused = try Self.call(
            app.tools,
            MCPTools.runDestructive,
            Self.command("focus")
        )
        #expect(refused["isError"] == .bool(true))
        #expect(app.sent.count == 1)
    }

    @Test("run sends a safe command; a setter is told temporary")
    func runSends() throws {
        let app = FakeApp()
        let read = try Self.call(
            app.tools,
            MCPTools.run,
            Self.command("version")
        )
        #expect(read["isError"] == .bool(false))
        #expect(!Self.text(read).contains(MCPWording.temporary))
        let set = try Self.call(
            app.tools,
            MCPTools.run,
            Self.command("border.set_width", [.number(4)])
        )
        #expect(Self.text(set).contains(MCPWording.temporary))
        let saved = try Self.call(
            app.tools,
            MCPTools.run,
            Self.command("set_default_profile", [.string("Work")])
        )
        #expect(!Self.text(saved).contains(MCPWording.temporary))
        #expect(
            app.sent.map(\.command)
                == ["version", "border.set_width", "set_default_profile"]
        )
    }

    @Test("an app refusal and a dead socket are tool errors")
    func failuresAreToolErrors() throws {
        let app = FakeApp()
        app.reply = { _ in .fail("expected width") }
        let refused = try Self.call(
            app.tools,
            MCPTools.run,
            Self.command("border.set_width")
        )
        #expect(refused["isError"] == .bool(true))
        #expect(Self.text(refused) == "expected width")
        var dead = MCPTools()
        dead.send = { _ in throw SocketError.connectFailed("refused") }
        let unreachable = try Self.call(
            dead,
            MCPTools.run,
            Self.command("version")
        )
        #expect(unreachable["isError"] == .bool(true))
        #expect(Self.text(unreachable).contains("not reachable"))
    }

    @Test("subscribe is refused: it streams instead of answering")
    func subscribeRefused() throws {
        let app = FakeApp()
        let result = try Self.call(
            app.tools,
            MCPTools.run,
            Self.command("subscribe")
        )
        #expect(result["isError"] == .bool(true))
        #expect(app.sent.isEmpty)
    }

    @Test("a batch with a destructive command runs none of it")
    func batchRefusesUpFront() throws {
        let app = FakeApp()
        let result = try Self.call(
            app.tools,
            MCPTools.runBatch,
            [
                "commands": .array([
                    .object(Self.command("version")),
                    .object(Self.command("close_window")),
                ])
            ]
        )
        #expect(result["isError"] == .bool(true))
        #expect(app.sent.isEmpty)
    }

    @Test("a batch stops at the first failure")
    func batchStops() throws {
        let app = FakeApp()
        app.reply = { request in
            request.command == "border.set_width"
                ? .fail("expected width") : .ok()
        }
        let result = try Self.call(
            app.tools,
            MCPTools.runBatch,
            [
                "commands": .array([
                    .object(Self.command("version")),
                    .object(Self.command("border.set_width")),
                    .object(Self.command("version")),
                ])
            ]
        )
        #expect(result["isError"] == .bool(true))
        #expect(app.sent.map(\.command) == ["version", "border.set_width"])
        guard case .object(let structured)? = result["structuredContent"]
        else {
            Issue.record("no structured result")
            return
        }
        #expect(structured["completed"] == .number(1))
    }

    @Test("the listing filters and marks destructive commands")
    func listingFilters() throws {
        let tools = FakeApp().tools
        let result = try Self.call(
            tools,
            MCPTools.listCommands,
            ["filter": .string("DELETE")]
        )
        let text = Self.text(result)
        #expect(text.contains("delete_space"))
        #expect(text.contains("[destructive]"))
        #expect(!text.contains("focus_space"))
        let all = Self.text(try Self.call(tools, MCPTools.listCommands))
        let listed = Set(
            all.split(separator: "\n").map {
                String($0.split(separator: " ").first ?? "")
            }
        )
        let luaOnly = APIReference.entries.filter { $0.command == nil }
        #expect(!luaOnly.isEmpty)
        for entry in luaOnly {
            #expect(!listed.contains(entry.qualifiedName))
        }
        #expect(!listed.contains(APIReference.socketOnlyCommand))
        #expect(listed.contains("focus"))
    }

    @Test("help answers from the binary, without the app")
    func helpIsLocal() throws {
        let app = FakeApp()
        let result = try Self.call(
            app.tools,
            MCPTools.help,
            ["name": .string("scroll.set_anchor")]
        )
        #expect(result["isError"] == .bool(false))
        #expect(Self.text(result).contains("anchor"))
        #expect(app.sent.isEmpty)
    }

    @Test("only run_destructive carries the destructive hint")
    func hints() {
        guard case .array(let tools) = MCPTools().definitions else {
            Issue.record("no tools")
            return
        }
        var destructive: [String] = []
        for case .object(let tool) in tools {
            guard case .object(let notes)? = tool["annotations"] else {
                continue
            }
            if notes["destructiveHint"] == .bool(true) {
                destructive.append(tool["name"]?.stringValue ?? "")
            }
        }
        #expect(destructive == [MCPTools.runDestructive])
    }
}
