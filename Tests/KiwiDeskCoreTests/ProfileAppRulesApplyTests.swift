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
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-profrules-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        config.appRules = [
            "Mail": SpaceID(1),
            "Music": SpaceID(2),
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
            "Mail": SpaceID(3),
            "Safari": SpaceID(4),
            "Music": nil,
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

        #expect(core.state.appRules["Mail"] == SpaceID(3))
        #expect(core.state.appRules["Safari"] == SpaceID(4))
        // Tombstone: the base pin is gone in this profile.
        #expect(core.state.appRules["Music"] == nil)
    }

    @Test("Profile without override reverts to base rules")
    func plainProfileRevertsToBase() throws {
        let core = makeGuiCore()
        try core.profiles.save(
            profile(named: "Work", appRules: override)
        )
        try core.profiles.save(profile(named: "Plain"))

        core.execute("load_profile", args: [.string("Work")])
        #expect(core.state.appRules["Mail"] == SpaceID(3))

        core.execute("load_profile", args: [.string("Plain")])
        #expect(core.state.appRules["Mail"] == SpaceID(1))
        #expect(core.state.appRules["Music"] == SpaceID(2))
        #expect(core.state.appRules["Safari"] == nil)
    }

    @Test("Reload keeps the active profile's override")
    func reloadKeepsActiveOverride() throws {
        let core = makeGuiCore()
        try core.profiles.save(
            profile(named: "Work", appRules: override)
        )
        core.execute("load_profile", args: [.string("Work")])

        // reapplyActiveProfileState inside loadConfig must
        // re-resolve with the adopted profile's override —
        // the structured base apply must not clobber it.
        core.loadConfig()

        #expect(core.state.appRules["Mail"] == SpaceID(3))
        #expect(core.state.appRules["Music"] == nil)
    }

    // MARK: - O7 all-or-nothing ownership

    @Test("Not GUI-managed: apply(profile:) leaves Lua rules")
    func nonGuiManagedKeepsLuaRules() throws {
        // No gui.json: Lua owns the rules entirely.
        let core = KiwiCore(
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

        core.execute("load_profile", args: [.string("Work")])

        // The Lua-declared rule survives — the profile's
        // override is structured-config vocabulary and must
        // not touch Lua-owned rules (O7).
        #expect(core.state.appRules["Mail"] == SpaceID(2))
        #expect(core.state.appRules["Safari"] == nil)
    }
}
