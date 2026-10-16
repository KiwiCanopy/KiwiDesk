import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The `kiwivision` tool (#1685 ▸ Ruling 2, #2103): its actions are
/// every `kiwivision.*` record `run` may send, the read among them,
/// its lead names the lens table's keys, and an app-wide KiwiVision
/// change `keep` cannot write points at Settings ▸ KiwiVision.
@Suite("MCP kiwivision tool")
struct MCPKiwiVisionTests {
    typealias FakeApp = MCPKeepTests.FakeApp

    static func vision(
        _ app: FakeApp,
        _ arguments: [String: JSONValue]
    ) throws -> [String: JSONValue] {
        try MCPKeepTests.call(app, MCPTools.kiwiVision, arguments)
    }

    /// The tool as a client lists it.
    static var tool: [String: JSONValue] {
        guard case .array(let tools) = MCPTools().definitions else {
            return [:]
        }
        for case .object(let tool) in tools
        where tool["name"]?.stringValue == MCPTools.kiwiVision {
            return tool
        }
        return [:]
    }

    static var actions: [String] {
        guard case .object(let input)? = tool["inputSchema"],
            case .object(let properties)? = input["properties"],
            case .object(let action)? = properties["action"],
            case .array(let values)? = action["enum"]
        else { return [] }
        return values.compactMap(\.stringValue)
    }

    @Test("every kiwivision record is an action, the read included")
    func actionsAreTheGroup() {
        let group = APIReference.groups.first { $0.name == "kiwivision" }
        let all = group?.entries.map(\.name) ?? []
        #expect(all.contains("current"))
        #expect(all.contains("delete_lens"))
        #expect(Self.actions == all)
    }

    @Test("the lead names every key a lens table takes")
    func leadNamesTheLensKeys() {
        let text = Self.tool["description"]?.stringValue ?? ""
        #expect(!VisionLens.tableKeys.isEmpty)
        for key in VisionLens.tableKeys {
            #expect(text.contains(key), "\(key)")
        }
    }

    @Test("an action sends its command with the record's arguments")
    func actionsSend() throws {
        let app = FakeApp()
        let table = #"{"name":"Writing","apps":["com.apple.Notes"]}"#
        let define = try Self.vision(
            app,
            ["action": .string("define_lens"), "lens": .string(table)]
        )
        #expect(define["isError"] == .bool(false))
        #expect(app.sent.last?.command == "kiwivision.define_lens")
        #expect(app.sent.last?.args == [.string(table)])
        _ = try Self.vision(
            app,
            ["action": .string("toggle"), "lens": .string("Writing")]
        )
        #expect(app.sent.last?.command == "kiwivision.toggle")
        #expect(app.sent.last?.args == [.string("Writing")])
        _ = try Self.vision(app, ["action": .string("current")])
        #expect(app.sent.last?.command == "kiwivision.current")
        #expect(app.sent.last?.args == nil)
        _ = try Self.vision(
            app,
            ["action": .string("delete_lens"), "lens": .string("Writing")]
        )
        #expect(app.sent.last?.command == "kiwivision.delete_lens")
    }

    /// The ids are the keep document's own, read off `groupsJSON`,
    /// so the sentence follows the leaf a report really names.
    @Test("a KiwiVision leaf keep cannot write names its page")
    func appWideLeafNamesThePage() {
        var settings = AppWideSettings()
        let before = settings.groupsJSON
        settings.visionDim = 15
        settings.visionLenses = [VisionLens(name: "Writing")]
        settings.refusalSound.toggle()
        let ids = KeepPointer.diff(before, settings.groupsJSON).map {
            KeepPointer.string([KeepRoot.appWide] + $0)
        }
        #expect(ids.count == 3)
        for id in ids {
            let leaf = MCPKeepTests.leaf(id, .none, .appWide)
            let told = MCPWording.unkeepable(leaf)
            let page =
                id.contains("kiwivision")
                ? "Settings ▸ KiwiVision" : "Settings ▸ General"
            #expect(told.contains(page), "\(id)")
            #expect(
                told.contains("make it there") == id.contains("lenses"),
                "\(id)"
            )
        }
    }
}
