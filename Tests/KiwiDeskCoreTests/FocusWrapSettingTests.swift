import Foundation
import Testing

@testable import KiwiDeskCore

/// `focus_wrap` is stored like the Space history (#2493, ruling
/// 2026-10-21): a global base in `gui.json` every profile uses, and
/// a sparse per-profile override, resolved live and written through
/// the "Applies to" table, a stored page's diff and the Lua verb.
@Suite("Focus wrap setting storage (#2493)", .serialized)
@MainActor
struct FocusWrapSettingTests {
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-focus-wrap-\(UUID().uuidString)")
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
        #expect(bare.focusWrap == .allScreens)
        var config = GuiConfig()
        config.focusWrap = .off
        let data = try JSONEncoder().encode(config)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""focus_wrap":"off""#))
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.focusWrap == .off)
    }

    @Test("a profile writes the key only where it diverges")
    func profileIsSparse() throws {
        let core = try makeCore()
        let plain = try String(
            contentsOf: core.profiles.fileURL(name: "Home"),
            encoding: .utf8
        )
        #expect(!plain.contains("focus_wrap"))
        var work = try core.profiles.read(name: "Work")
        work.focusWrap = .off
        try core.profiles.write(work)
        let written = try String(
            contentsOf: core.profiles.fileURL(name: "Work"),
            encoding: .utf8
        )
        #expect(written.contains(#""focus_wrap""#))
        let reread = try core.profiles.read(name: "Work")
        #expect(reread.focusWrap == .off)
    }

    @Test("the table writes a listed value to the profile alone")
    func reachWritesTheOverride() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        let key = RuleReachTable<FocusWrap>.focusWrapKey
        snapshot.focusWrap.apply(
            key,
            value: .off,
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(snapshot.isEdited)
        try core.saveRuleReach(snapshot)
        let work = try core.profiles.read(name: "Work")
        #expect(work.focusWrap == .off)
        #expect(try core.profiles.read(name: "Home").focusWrap == nil)
        #expect(core.guiConfigStore.load()?.focusWrap == .allScreens)
    }

    @Test("a shared value moves the base, and the live resolve")
    func reachMovesTheBase() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.focusWrap.apply(
            RuleReachTable<FocusWrap>.focusWrapKey,
            value: .off,
            reach: .shared(joining: []),
            editing: "Home"
        )
        try core.saveRuleReach(snapshot)
        #expect(core.guiConfigStore.load()?.focusWrap == .off)
        #expect(core.focusWrap.mode == .off)
    }

    @Test("a stored page resolves the override and diffs it back")
    func storedPageRoundTrips() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.focusWrap = .off
        try core.profiles.write(work)
        var page = try core.loadGuiConfig(editing: "Work")
        #expect(page.focusWrap == .off)
        page.focusWrap = .allScreens
        try core.overwriteProfile(
            named: "Work",
            with: page,
            writingRules: true
        )
        // Back on the base: the key leaves the file.
        #expect(try core.profiles.read(name: "Work").focusWrap == nil)
    }

    @Test("a profile apply resolves its override over the base")
    func profileApplyResolves() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.focusWrap = .off
        core.reapplyStructuredOverrides(work)
        #expect(core.focusWrap.mode == .off)
        core.reapplyStructuredOverrides(nil)
        #expect(core.focusWrap.mode == .allScreens)
    }
}
