import Foundation
import Testing

@testable import KiwiDeskCore

/// Integration tests for the per-profile app-rule tier (#109):
/// `apply(profile:)` re-resolves `state.appRules` with the
/// applied profile's `AppRuleOverride` — base rules the profile
/// does not mention survive, a tombstone un-pins, and a profile
/// without an override reverts to the base (the keybinding
/// tier's twin, `ProfileKeybindingApplyTests`).
@Suite("Profile apply app rules (#109)", .serialized)
@MainActor
struct ProfileAppRulesApplyTests {

    // MARK: - Helpers

    private func makeGuiCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-profrules-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        config.appRules = [
            "mail": SpaceID(1),
            "music": SpaceID(2),
        ]
        try? core.guiConfigStore.save(config)
        return core
    }

    private func profile(
        named name: String,
        appRules: AppRuleOverride? = nil
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [
                MonitorSet(monitors: ["A:100x100"])
            ],
            spaceModes: [:],
            settings: TilingSettings(),
            appRules: appRules
        )
    }

    /// Re-pins Mail, adds Safari, un-pins Music.
    private var override: AppRuleOverride {
        AppRuleOverride(rules: [
            "mail": SpaceID(3),
            "safari": SpaceID(4),
            "music": nil,
        ])
    }

    // MARK: - Apply

    /// Also pins the pre-VM ordering inside
    /// `reapplyStructuredOverrides`: this core never ran
    /// `loadConfig`, so `keys.lua` is nil and the rule tier
    /// must apply BEFORE the keybinding half's VM guard.
    @Test("load_profile resolves the override onto the base")
    func loadProfileResolvesOverride() throws {
        let core = makeGuiCore()
        try core.profiles.save(
            profile(named: "Work", appRules: override)
        )

        let result = core.execute(
            "load_profile",
            args: [.string("Work")]
        )
        #expect(result.isSuccess)

        #expect(core.state.appRules["mail"] == SpaceID(3))
        #expect(core.state.appRules["safari"] == SpaceID(4))
        // Tombstone: the base pin is gone in this profile.
        #expect(core.state.appRules["music"] == nil)
    }

    @Test("Profile without override reverts to base rules")
    func plainProfileRevertsToBase() throws {
        let core = makeGuiCore()
        try core.profiles.save(
            profile(named: "Work", appRules: override)
        )
        try core.profiles.save(profile(named: "Plain"))

        _ = core.execute("load_profile", args: [.string("Work")])
        #expect(core.state.appRules["mail"] == SpaceID(3))

        _ = core.execute("load_profile", args: [.string("Plain")])
        #expect(core.state.appRules["mail"] == SpaceID(1))
        #expect(core.state.appRules["music"] == SpaceID(2))
        #expect(core.state.appRules["safari"] == nil)
    }

    @Test("Reload keeps the active profile's override")
    func reloadKeepsActiveOverride() throws {
        let core = makeGuiCore()
        try core.profiles.save(
            profile(named: "Work", appRules: override)
        )
        _ = core.execute("load_profile", args: [.string("Work")])

        // reapplyActiveProfileState inside loadConfig must
        // re-resolve with the adopted profile's override —
        // the structured base apply must not clobber it.
        core.loadConfig()

        #expect(core.state.appRules["mail"] == SpaceID(3))
        #expect(core.state.appRules["music"] == nil)
    }

    // MARK: - Lua-owned global base

    @Test("Not GUI-managed: profile resolves onto Lua base")
    func nonGuiManagedResolvesLuaRules() throws {
        // No gui.json: Lua owns the global base.
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-profrules-\(UUID().uuidString)"
                )
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        let lua = """
            app_rules = { Mail = "2" }
            """
        try lua.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        try core.profiles.save(
            profile(named: "Work", appRules: override)
        )

        _ = core.execute("load_profile", args: [.string("Work")])

        #expect(core.state.appRules["mail"] == SpaceID(3))
        #expect(core.state.appRules["safari"] == SpaceID(4))
    }

    @Test("GUI base tombstone matches bundle id case-insensitively")
    func guiMixedCaseTombstone() throws {
        let core = makeGuiCore()
        let tombstone = AppRuleOverride(rules: ["MAIL": nil])
        try core.profiles.save(
            profile(named: "Work", appRules: tombstone)
        )

        _ = core.execute("load_profile", args: [.string("Work")])

        #expect(core.state.appRules["mail"] == nil)
        #expect(core.state.appRules["music"] == SpaceID(2))
    }

    @Test("Lua base tombstone matches bundle id case-insensitively")
    func luaMixedCaseTombstone() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-profrules-\(UUID().uuidString)"
                )
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "app_rules = { Mail = \"2\" }".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        let tombstone = AppRuleOverride(rules: ["MAIL": nil])
        try core.profiles.save(
            profile(named: "Work", appRules: tombstone)
        )

        _ = core.execute("load_profile", args: [.string("Work")])

        #expect(core.state.appRules["mail"] == nil)
    }
}
