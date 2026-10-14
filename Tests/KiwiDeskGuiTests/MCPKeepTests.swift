import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The keep half of `kiwidesk mcp` (#1685 ▸ Ruling 4): the ledger
/// holds only the leaves Core's change reports named, every result
/// tells what is live and not kept, and `keep` sends exactly those
/// leaves to `keep_settings`.
@Suite("MCP keep")
struct MCPKeepTests {
    /// Answers each request, attaching the report `changes` gives.
    final class FakeApp: @unchecked Sendable {
        var sent: [CommandRequest] = []
        var epoch = 1
        var touched: [String: [TouchedLeaf]] = [:]
        var keepAnswer: JSONValue = .object([:])

        lazy var tools: MCPTools = {
            var tools = MCPTools()
            tools.send = { request in self.answer(request) }
            return tools
        }()

        func answer(_ request: CommandRequest) -> CommandResponse {
            sent.append(request)
            var response = CommandResponse.ok(
                request.command == MCPTools.keepCommand ? keepAnswer : nil
            )
            if request.reportChanges == true {
                response.changes = ChangeReport(
                    epoch: epoch,
                    profile: "Work",
                    touched: touched[request.command] ?? []
                )
            }
            return response
        }
    }

    static func leaf(
        _ id: String,
        _ owner: KeepOwner = .profile,
        _ refusal: NotKeepable? = nil
    ) -> TouchedLeaf {
        TouchedLeaf(id: id, owner: owner, notKeepable: refusal)
    }

    static func call(
        _ app: FakeApp,
        _ name: String,
        _ arguments: [String: JSONValue] = [:]
    ) throws -> [String: JSONValue] {
        let result = try app.tools.call([
            "name": .string(name), "arguments": .object(arguments),
        ])
        guard case .object(let fields) = result else { return [:] }
        return fields
    }

    static func run(_ app: FakeApp, _ command: String) throws
        -> [String: JSONValue]
    {
        try call(app, MCPTools.run, ["command": .string(command)])
    }

    static func text(_ result: [String: JSONValue]) -> String {
        guard case .array(let items)? = result["content"] else { return "" }
        return items.compactMap { item -> String? in
            guard case .object(let fields) = item else { return nil }
            return fields["text"]?.stringValue
        }.joined(separator: "\n")
    }

    static func status(_ result: [String: JSONValue]) -> [String: JSONValue]? {
        guard case .object(let structured)? = result["structuredContent"],
            case .object(let status)? = structured["keep_status"]
        else { return nil }
        return status
    }

    @Test("a reported change stays told on every later result")
    func changeIsToldUntilKept() throws {
        let app = FakeApp()
        app.touched["border.set_width"] = [
            Self.leaf("/settings/border/width")
        ]
        let quiet = try Self.run(app, "version")
        #expect(Self.status(quiet) == nil)
        let set = try Self.run(app, "border.set_width")
        #expect(Self.status(set)?["pending"] == .number(1))
        #expect(Self.text(set).contains("Not kept yet: 1"))
        #expect(Self.text(set).contains("\"Work\""))
        let later = try Self.call(app, MCPTools.getState)
        #expect(Self.status(later)?["pending"] == .number(1))
    }

    @Test("keep sends the pending ids and ends them")
    func keepSendsPending() throws {
        let app = FakeApp()
        app.touched["set_mode"] = [
            Self.leaf("/space_modes/2"), Self.leaf("/settings/gap/global"),
        ]
        _ = try Self.run(app, "set_mode")
        app.keepAnswer = .object([
            "profile": .string("Work"),
            "kept": .array([
                .object([
                    "id": .string("/settings/gap/global"),
                    "owner": .string("profile"),
                ]),
                .object([
                    "id": .string("/space_modes/2"),
                    "owner": .string("profile"),
                ]),
            ]),
        ])
        let kept = try Self.call(app, MCPTools.keep)
        #expect(kept["isError"] == .bool(false))
        let sent = app.sent.last
        #expect(sent?.command == MCPTools.keepCommand)
        #expect(
            sent?.args == [
                .string("/settings/gap/global"), .string("/space_modes/2"),
            ]
        )
        #expect(Self.text(kept).contains("Kept 2"))
        #expect(Self.status(kept) == nil)
        #expect(Self.status(try Self.run(app, "version")) == nil)
    }

    @Test("keep refuses an id no report named, and sends nothing")
    func keepRefusesStrangers() throws {
        let app = FakeApp()
        app.touched["border.set_width"] = [
            Self.leaf("/settings/border/width")
        ]
        _ = try Self.run(app, "border.set_width")
        let count = app.sent.count
        let refused = try Self.call(
            app,
            MCPTools.keep,
            ["ids": .array([.string("/settings/gap/global")])]
        )
        #expect(refused["isError"] == .bool(true))
        #expect(app.sent.count == count)
        let empty = try Self.call(FakeApp(), MCPTools.keep)
        #expect(Self.text(empty) == MCPWording.nothingToKeep)
    }

    @Test("a moved epoch reports the pending changes replaced, once")
    func epochReplaces() throws {
        let app = FakeApp()
        app.touched["border.set_width"] = [
            Self.leaf("/settings/border/width")
        ]
        _ = try Self.run(app, "border.set_width")
        app.epoch = 2
        let reloaded = try Self.run(app, "version")
        #expect(
            Self.status(reloaded)?["replaced"]
                == .array([.string("/settings/border/width")])
        )
        #expect(Self.status(reloaded)?["pending"] == .number(0))
        #expect(Self.status(try Self.run(app, "version")) == nil)
    }

    @Test("an unkeepable leaf is told, never counted or sent")
    func unkeepableIsToldNotKept() throws {
        let app = FakeApp()
        app.touched["quit.set_layout"] = [
            Self.leaf("/app_wide/quitLayout", .none, .appWide)
        ]
        let result = try Self.run(app, "quit.set_layout")
        #expect(Self.status(result)?["pending"] == .number(0))
        #expect(Self.text(result).contains("cannot be kept"))
        let count = app.sent.count
        let keep = try Self.call(app, MCPTools.keep)
        #expect(Self.text(keep).contains(MCPWording.nothingToKeep))
        #expect(app.sent.count == count)
    }

    @Test("a shared-look keep names the profiles wearing it")
    func sharedLookNamesFollowers() throws {
        let app = FakeApp()
        app.touched["kiwishelf.set_thickness"] = [
            Self.leaf("/settings/kiwishelf/thickness", .sharedLook)
        ]
        let set = try Self.run(app, "kiwishelf.set_thickness")
        #expect(Self.text(set).contains("shared look"))
        app.keepAnswer = .object([
            "profile": .string("Work"),
            "kept": .array([
                .object([
                    "id": .string("/settings/kiwishelf/thickness"),
                    "owner": .string("shared_look"),
                ])
            ]),
            "followers": .array([.string("Home"), .string("Work")]),
        ])
        let kept = try Self.call(app, MCPTools.keep)
        #expect(Self.text(kept).contains("Home, Work"))
    }

    @Test("run_batch carries the status once")
    func batchCarriesStatusOnce() throws {
        let app = FakeApp()
        app.touched["border.set_width"] = [
            Self.leaf("/settings/border/width")
        ]
        let step: JSONValue = .object(["command": .string("border.set_width")])
        let result = try Self.call(
            app,
            MCPTools.runBatch,
            ["commands": .array([step, step])]
        )
        #expect(Self.status(result)?["pending"] == .number(1))
        let told = Self.text(result).components(separatedBy: "Not kept yet")
        #expect(told.count == 2)
    }
}
