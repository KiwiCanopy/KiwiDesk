import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwidesk mcp`'s tools at their edges (#1685): a name the
/// binary does not know, an alias, a reply that is no object, an
/// app that does not answer, and the registry itself.
@Suite("MCP tools at the edges")
struct MCPToolsEdgeTests {
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

    static func command(_ name: String) -> [String: JSONValue] {
        ["command": .string(name)]
    }

    @Test("an unknown command is refused, never forwarded")
    func unknownIsRefused() throws {
        let app = FakeApp()
        let result = try Self.call(
            app.tools,
            MCPTools.run,
            Self.command("focsu")
        )
        #expect(result["isError"] == .bool(true))
        #expect(Self.text(result).contains("did you mean"))
        #expect(app.sent.isEmpty)
    }

    @Test("an alias is sent as the command it names")
    func aliasResolves() throws {
        let app = FakeApp()
        let entry = try #require(
            APIReference.entries.first {
                !$0.aliases.isEmpty && $0.command != nil
                    && !APIReference.isDestructive($0)
            }
        )
        _ = try Self.call(
            app.tools,
            MCPTools.run,
            Self.command(try #require(entry.aliases.first))
        )
        #expect(app.sent.map(\.command) == [entry.command])
    }

    @Test("structured content is an object whatever the app sent")
    func structuredIsAnObject() throws {
        let app = FakeApp()
        app.reply = { _ in .ok(.array([.string("a")])) }
        let result = try Self.call(
            app.tools,
            MCPTools.run,
            Self.command("version")
        )
        guard case .object(let fields)? = result["structuredContent"]
        else {
            Issue.record("structuredContent is not an object")
            return
        }
        #expect(fields["value"] == .array([.string("a")]))
    }

    @Test("a call the app took but did not answer may have run")
    func timeoutIsNotUnreachable() throws {
        var hung = MCPTools()
        hung.send = { _ in throw SocketError.closed }
        let result = try Self.call(
            hung,
            MCPTools.run,
            Self.command("version")
        )
        #expect(Self.text(result).contains("may have run"))
        var down = MCPTools()
        down.send = { _ in throw SocketError.connectFailed("refused") }
        let dead = try Self.call(
            down,
            MCPTools.run,
            Self.command("version")
        )
        #expect(Self.text(dead).contains("not reachable"))
    }

    @Test("every listed tool answers its own name")
    func everyToolIsCallable() throws {
        guard case .array(let defined) = MCPTools().definitions else {
            Issue.record("no tools")
            return
        }
        let names = defined.compactMap { tool -> String? in
            guard case .object(let fields) = tool else { return nil }
            return fields["name"]?.stringValue
        }
        // The ruled tool set (#1685 ▸ Ruling 2–4); a domain tool
        // joins it by ruling.
        #expect(
            Set(names) == [
                "list_commands", "help", "get_state", "run",
                "run_batch", "run_destructive", "keep", "looks",
                "app_rules",
            ]
        )
        #expect(Set(names).count == names.count)
        for name in names {
            #expect(throws: Never.self) {
                _ = try FakeApp().tools.call(["name": .string(name)])
            }
        }
    }

    @Test("get_state forwards the app's own answer")
    func getStateForwards() throws {
        let app = FakeApp()
        app.reply = { _ in .ok(.object(["active_space": .string("1")])) }
        let result = try Self.call(app.tools, MCPTools.getState)
        #expect(result["isError"] == .bool(false))
        #expect(app.sent.map(\.command) == ["get_state"])
        #expect(Self.text(result).contains("active_space"))
    }

    /// A command a tool's description names is one `run` sends,
    /// or a destructive one `run_destructive` sends — never one
    /// both refuse, such as `keep_settings` (#1685 ▸ Ruling 4).
    @Test("every command a description names is reachable")
    func descriptionsNameReachableCommands() {
        guard case .array(let tools) = MCPTools().definitions else {
            Issue.record("no tools")
            return
        }
        let named = APIReference.entries.filter {
            $0.qualifiedName.contains("_") || $0.qualifiedName.contains(".")
        }
        var checked = 0
        for case .object(let tool) in tools {
            let text = tool["description"]?.stringValue ?? ""
            let words = Set(
                text.split { !($0.isLetter || $0 == "_" || $0 == ".") }
                    .map { $0.trimmingCharacters(in: ["."]) }
            )
            for entry in named where words.contains(entry.qualifiedName) {
                checked += 1
                let destructive = APIReference.isDestructive(entry)
                let probe = MCPTools.request(
                    from: ["command": .string(entry.qualifiedName)],
                    destructive: destructive
                )
                if case .failure(let refusal) = probe {
                    Issue.record("\(entry.qualifiedName): \(refusal.reason)")
                }
            }
        }
        #expect(checked > 0)
    }
}
