import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `SettingsModel.draftDiff` serves the last walk while its inputs
/// stand still (#3060). These hold that a change to any input it
/// reads is a new walk, and that its key names every input
/// `SettingsDraftDiff.between` takes, so a parameter added there
/// cannot be served stale.
@Suite("Draft diff cache")
@MainActor
struct DraftDiffCacheTests {
    @Test("an edit after a read is in the next read")
    func editAfterReadIsSeen() {
        let model = makeTestModel()
        #expect(model.draftDiff.changedSettings.isEmpty)
        model.config.settings.kiwishelf.minimum += 5
        #expect(!model.draftDiff.changedSettings.isEmpty)
        #expect(model.draftChangeCount >= 1)
        // The rows the pill lists read the same diff.
        #expect(!SettingsDiffRowSource.rows(for: model).isEmpty)
    }

    @Test("a moved baseline is a new walk")
    func baselineMoveIsSeen() {
        let model = makeTestModel()
        model.config.settings.kiwishelf.minimum += 5
        #expect(!model.draftDiff.changedSettings.isEmpty)
        model.cleanConfig = model.config
        #expect(model.draftDiff.changedSettings.isEmpty)
    }

    @Test("a Lua edit is a new walk")
    func luaEditIsSeen() {
        let model = makeTestModel()
        #expect(!model.draftDiff.luaChanged)
        model.luaSource = model.cleanLuaSource + "\n-- edited"
        #expect(model.draftDiff.luaChanged)
    }

    /// The key's fields are `between`'s parameters, read from its
    /// declaration: a parameter the key lacks would be served from
    /// whichever walk read it last.
    @Test("the key names every input the walk takes")
    func keyCoversTheWalk() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/SettingsDraftDiff.swift"
                    ),
                encoding: .utf8
            )
        )
        let start = try #require(source.range(of: "static func between("))
        let end = try #require(
            source.range(of: ")", range: start.upperBound..<source.endIndex)
        )
        let parameters = source[start.upperBound..<end.lowerBound]
            .split(separator: ",")
            .compactMap {
                $0.split(separator: ":").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        #expect(parameters.count == 4)
        let key = DraftDiffCache.Key(
            config: GuiConfig(),
            cleanConfig: GuiConfig(),
            luaSource: "",
            cleanLuaSource: ""
        )
        let fields = Mirror(reflecting: key).children.compactMap(\.label)
        #expect(fields == parameters)
    }
}
