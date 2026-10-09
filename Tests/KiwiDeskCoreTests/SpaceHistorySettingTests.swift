import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_history` is stored like the shortcuts (#1655, ruling
/// 2026-10-09): a global base in `gui.json` every profile uses, and
/// a sparse per-profile override, resolved live and written through
/// the "Applies to" table, a stored page's diff and the Lua verb.
@Suite("Space history setting storage (#1655)", .serialized)
@MainActor
struct SpaceHistorySettingTests {
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-history-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        for name in ["Home", "Work"] {
            try core.profiles.save(
                Profile(
                    name: name,
                    monitorSets: [MonitorSet(monitors: ["\(name):1x1"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            )
        }
        return core
    }

    @Test("gui.json: absent reads the default, a value round-trips")
    func guiConfigRoundTrip() throws {
        let bare = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data(#"{"format": 1}"#.utf8)
        )
        #expect(bare.spaceHistory == .perScreen)
        var config = GuiConfig()
        config.spaceHistory = .allScreens
        let data = try JSONEncoder().encode(config)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""space_history":"all_screens""#))
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.spaceHistory == .allScreens)
    }

    @Test("a profile writes the key only where it diverges")
    func profileIsSparse() throws {
        let core = try makeCore()
        let plain = try String(
            contentsOf: core.profiles.fileURL(name: "Home"),
            encoding: .utf8
        )
        #expect(!plain.contains("space_history"))
        var work = try core.profiles.read(name: "Work")
        work.spaceHistory = .allScreens
        try core.profiles.write(work)
        let work = try core.profiles.read(name: "Work")
        #expect(work.spaceHistory == .allScreens)
    }

    @Test("the table writes a listed value to the profile alone")
    func reachWritesTheOverride() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        let key = RuleReachTable<SpaceHistoryKind>.spaceHistoryKey
        snapshot.spaceHistory.apply(
            key,
            value: .allScreens,
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(snapshot.isEdited)
        try core.saveRuleReach(snapshot)
        let work = try core.profiles.read(name: "Work")
        #expect(work.spaceHistory == .allScreens)
        #expect(try core.profiles.read(name: "Home").spaceHistory == nil)
        #expect(core.guiConfigStore.load()?.spaceHistory == .perScreen)
    }

    @Test("a shared value moves the base, and the live resolve")
    func reachMovesTheBase() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.spaceHistory.apply(
            RuleReachTable<SpaceHistoryKind>.spaceHistoryKey,
            value: .allScreens,
            reach: .shared(joining: []),
            editing: "Home"
        )
        try core.saveRuleReach(snapshot)
        #expect(core.guiConfigStore.load()?.spaceHistory == .allScreens)
        #expect(core.spaceHistory.kind == .allScreens)
    }

    @Test("a stored page resolves the override and diffs it back")
    func storedPageRoundTrips() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.spaceHistory = .allScreens
        try core.profiles.write(work)
        var page = try core.loadGuiConfig(editing: "Work")
        #expect(page.spaceHistory == .allScreens)
        page.spaceHistory = .perScreen
        try core.overwriteProfile(
            named: "Work",
            with: page,
            writingRules: true
        )
        // Back on the base: the key leaves the file.
        #expect(try core.profiles.read(name: "Work").spaceHistory == nil)
    }

    @Test("a profile apply resolves its override over the base")
    func profileApplyResolves() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.spaceHistory = .allScreens
        core.reapplyStructuredOverrides(
            profileModes: nil,
            profileAppRules: nil,
            profileFloatRules: nil,
            profileIgnoreRules: nil,
            profileScrollGesture: nil,
            profileSpaceHistory: work.spaceHistory
        )
        #expect(core.spaceHistory.kind == .allScreens)
        core.reapplyStructuredOverrides(
            profileModes: nil,
            profileAppRules: nil,
            profileFloatRules: nil,
            profileIgnoreRules: nil,
            profileScrollGesture: nil,
            profileSpaceHistory: nil
        )
        #expect(core.spaceHistory.kind == .perScreen)
    }

    @Test("one screen greys the choice; more, or unknown, offer it")
    func choiceMatters() {
        #expect(!SpaceHistoryKind.choiceMatters(screens: 1))
        #expect(SpaceHistoryKind.choiceMatters(screens: 2))
        #expect(SpaceHistoryKind.choiceMatters(screens: 0))
    }
}
