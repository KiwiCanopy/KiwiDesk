import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `SettingsModel.draftDiff` serves the last walk while its inputs
/// stand still (#3060). These hold that a write to any input it
/// reads is a new walk, the pill's rows reading the same diff.
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

    /// Every write to an input is a new walk, an `==`-equal one
    /// included: `GuiConfig ==` skips fields the walk reads (a
    /// binding's id, a Desktop entry's name), so the cache keys on the
    /// writes rather than the values.
    @Test("every write to an input is a new walk")
    func everyWriteIsANewWalk() {
        let model = makeTestModel()
        let writes: [(String, () -> Void)] = [
            ("config", { model.config = model.config }),
            ("cleanConfig", { model.cleanConfig = model.cleanConfig }),
            ("luaSource", { model.luaSource = model.luaSource }),
            (
                "cleanLuaSource",
                { model.cleanLuaSource = model.cleanLuaSource }
            ),
        ]
        for (name, write) in writes {
            _ = model.draftDiff
            #expect(model.draftMemo.value != nil, "\(name)")
            write()
            #expect(
                model.draftMemo.value == nil,
                "\(name) kept the last walk"
            )
        }
    }

    /// Unchanged inputs are served from the last walk.
    @Test("a read with no write is served from the last walk")
    func unchangedReadIsServed() {
        let model = makeTestModel()
        _ = model.draftDiff
        let writes = model.draftMemo.writes
        #expect(model.draftMemo.value != nil)
        _ = model.draftDiff
        #expect(model.draftMemo.writes == writes)
        #expect(model.draftMemo.value != nil)
    }

    /// The pill's rows take the cached walk rather than one of their
    /// own: a direct call is right and walks both configs per render.
    @Test("the pill's rows read the cached diff")
    func rowsReadTheCache() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/SettingsDetailPanel.swift"
                    ),
                encoding: .utf8
            )
        )
        .filter { !$0.isWhitespace }
        #expect(source.contains("letdiff=model.draftDiff"))
        #expect(!source.contains("SettingsDraftDiff.between("))
    }
}
