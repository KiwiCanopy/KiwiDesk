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
            ["action": .string("define_lens"), "table": .string(table)]
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

    /// The keep document's leaf for one change of `settings`.
    static func leafID(
        _ change: (inout AppWideSettings) -> Void
    ) -> [String] {
        var settings = AppWideSettings()
        let before = settings.groupsJSON
        change(&settings)
        return KeepPointer.diff(before, settings.groupsJSON).map {
            KeepPointer.string([KeepRoot.appWide] + $0)
        }
    }

    /// The ids and the KiwiVision group are the keep document's own,
    /// read off `groupsJSON` and the stored lens key, so a rename of
    /// either reds rather than leaving the sentence on General.
    @Test("a KiwiVision leaf keep cannot write names its page")
    func appWideLeafNamesThePage() throws {
        let dim = Self.leafID { $0.visionDim = 15 }
        let lens = Self.leafID {
            $0.visionLenses = [VisionLens(name: "Writing")]
        }
        let sound = Self.leafID { $0.refusalSound.toggle() }
        let ids = try #require(
            [dim, lens, sound].allSatisfy { $0.count == 1 }
                ? [dim[0], lens[0], sound[0]] : nil
        )
        let group = try #require(
            KeepPointer.path(ids[0])?.dropFirst().first
        )
        let lensKey = AppWideSettings.Vision.CodingKeys.lenses.rawValue
        #expect(
            KeepPointer.path(ids[1]) == [KeepRoot.appWide, group, lensKey]
        )
        let told = ids.map {
            MCPWording.unkeepable(MCPKeepTests.leaf($0, .none, .appWide))
        }
        #expect(told[0].contains("Settings ▸ KiwiVision"))
        #expect(!told[0].contains("define or delete the lens"))
        #expect(told[1].contains("Settings ▸ KiwiVision"))
        #expect(told[1].contains("define or delete the lens there"))
        #expect(told[2].contains("Settings ▸ General"))
        for sentence in told {
            #expect(sentence.contains("a config reload or restart"))
        }
    }
}
