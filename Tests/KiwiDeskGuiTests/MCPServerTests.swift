import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwidesk mcp`'s protocol half (#1685): one server answering a
/// legacy client's `initialize` and a modern client's per-request
/// version alike.
@Suite("MCP server protocol")
struct MCPServerTests {
    static let modern = MCPProtocol.modern[0]

    static func server() -> MCPServer {
        var tools = MCPTools()
        tools.send = { _ in .ok() }
        return MCPServer(tools: tools)
    }

    static func object(_ value: JSONValue?) -> [String: JSONValue] {
        guard case .object(let fields)? = value else { return [:] }
        return fields
    }

    static func ask(
        _ method: String,
        id: String = "1",
        params: [String: JSONValue] = [:]
    ) -> [String: JSONValue] {
        let line = MCPReply.line(
            .object([
                "jsonrpc": .string("2.0"),
                "id": .string(id),
                "method": .string(method),
                "params": .object(params),
            ])
        )
        return object(server().reply(to: line ?? ""))
    }

    static func meta(_ version: String) -> [String: JSONValue] {
        [
            "_meta": .object([
                MCPProtocol.versionKey: .string(version)
            ])
        ]
    }

    @Test("initialize echoes a served legacy version")
    func initializeNegotiates() {
        let reply = Self.ask(
            "initialize",
            params: ["protocolVersion": .string("2025-06-18")]
        )
        let result = Self.object(reply["result"])
        #expect(result["protocolVersion"] == .string("2025-06-18"))
        #expect(result["serverInfo"] != nil)
        let unknown = Self.ask(
            "initialize",
            params: ["protocolVersion": .string("2024-01-01")]
        )
        #expect(
            Self.object(unknown["result"])["protocolVersion"]
                == .string(MCPProtocol.legacy[0])
        )
    }

    @Test("discovery lists every served version")
    func discoverLists() {
        let reply = Self.ask(
            "server/discover",
            params: Self.meta(Self.modern)
        )
        let result = Self.object(reply["result"])
        #expect(result["resultType"] == .string("complete"))
        guard case .array(let versions)? = result["supportedVersions"]
        else {
            Issue.record("no supportedVersions")
            return
        }
        let served = MCPProtocol.modern + MCPProtocol.legacy
        #expect(versions == served.map(JSONValue.string))
    }

    @Test("a modern request for an unserved version is refused")
    func unsupportedVersion() {
        let reply = Self.ask("tools/list", params: Self.meta("1900-01-01"))
        let error = Self.object(reply["error"])
        #expect(error["code"] == .number(-32022))
        let data = Self.object(error["data"])
        #expect(data["requested"] == .string("1900-01-01"))
    }

    @Test("a modern list carries its cache fields; a legacy one not")
    func listShapes() {
        let modern = Self.object(
            Self.ask("tools/list", params: Self.meta(Self.modern))["result"]
        )
        #expect(modern["resultType"] == .string("complete"))
        #expect(modern["ttlMs"] != nil)
        #expect(modern["cacheScope"] != nil)
        let legacy = Self.object(Self.ask("tools/list")["result"])
        #expect(legacy["tools"] != nil)
        #expect(legacy["resultType"] == nil)
        #expect(legacy["ttlMs"] == nil)
    }

    @Test("a notification gets no reply; garbage gets a parse error")
    func notificationsAndGarbage() {
        let note = MCPReply.line(
            .object([
                "jsonrpc": .string("2.0"),
                "method": .string("notifications/initialized"),
            ])
        )
        #expect(Self.server().reply(to: note ?? "") == nil)
        let garbage = Self.object(Self.server().reply(to: "{nope"))
        #expect(Self.object(garbage["error"])["code"] == .number(-32700))
    }

    @Test("an unknown method and an unknown tool are protocol errors")
    func unknownNames() {
        let method = Self.ask("resources/list")
        #expect(Self.object(method["error"])["code"] == .number(-32601))
        let tool = Self.ask(
            "tools/call",
            params: ["name": .string("format_disk")]
        )
        #expect(Self.object(tool["error"])["code"] == .number(-32602))
    }

    @Test("a reply is one line")
    func repliesAreOneLine() {
        let reply = Self.server().reply(
            to: #"{"jsonrpc":"2.0","id":1,"method":"server/discover"}"#
        )
        let line = reply.flatMap(MCPReply.line) ?? ""
        #expect(!line.isEmpty)
        #expect(!line.contains("\n"))
    }

    @Test("nothing in the MCP tree prints to stdout")
    func stdoutCarriesOnlyReplies() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let files = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk/MCP")
        )
        #expect(!files.isEmpty, "the MCP tree moved; this scans nothing")
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            #expect(
                !text.contains("print("),
                "\(file.lastPathComponent) prints; stdout is JSON-RPC"
            )
        }
    }
}
