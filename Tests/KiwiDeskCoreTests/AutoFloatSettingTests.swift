import Foundation
import Testing

@testable import KiwiDeskCore

/// `float_automatically` and `tile_rules` (#2173) are stored like
/// the other window-rule families: a global base in `gui.json` or
/// `init.lua`, and a sparse per-profile override, resolved into
/// the guess detection reads.
@Suite("Automatic float setting storage (#2173)", .serialized)
@MainActor
struct AutoFloatSettingTests {
    private static let steam = "com.valvesoftware.steam"
    private static let mail = "com.apple.mail"

    private func makeCore(lua: String? = nil) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-autofloat-\(UUID().uuidString)")
        )
        if let lua {
            try FileManager.default.createDirectory(
                at: core.configDirectory,
                withIntermediateDirectories: true
            )
            try lua.write(
                to: core.configURL,
                atomically: true,
                encoding: .utf8
            )
            core.loadConfig()
        } else {
            var config = GuiConfig()
            config.tileRules = [Self.steam]
            try core.guiConfigStore.save(config)
        }
        return core
    }

    private func load(_ profile: Profile, into core: KiwiCore) throws {
        try core.profiles.save(profile)
        #expect(
            core.execute("load_profile", args: [.string(profile.name)])
                .isSuccess
        )
    }

    private func profile(
        _ name: String,
        floatAutomatically: Bool? = nil,
        tileRules: RuleListOverride? = nil
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaceModes: [:],
            settings: TilingSettings(),
            floatAutomatically: floatAutomatically,
            tileRules: tileRules
        )
    }

    private func guess(_ core: KiwiCore) -> FloatGuess {
        core.eventLoop.floatRules.guess
    }

    @Test("gui.json: absent reads the defaults, values round-trip")
    func guiConfigRoundTrip() throws {
        let bare = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data(#"{"format": 1}"#.utf8)
        )
        #expect(bare.floatAutomatically)
        #expect(bare.tileRules.isEmpty)
        var config = GuiConfig()
        config.floatAutomatically = false
        config.tileRules = [Self.steam]
        let data = try JSONEncoder().encode(config)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""float_automatically":false"#))
        #expect(text.contains(#""tile_rules":["com.valvesoftware.steam"]"#))
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(!back.floatAutomatically)
        #expect(back.tileRules == [Self.steam])
    }

    @Test("a profile writes the keys only where it diverges")
    func profileIsSparse() throws {
        let plain = try JSONEncoder().encode(profile("Home"))
        let text = String(decoding: plain, as: UTF8.self)
        #expect(!text.contains("float_automatically"))
        #expect(!text.contains("tile_rules"))
        let data = try JSONEncoder().encode(
            profile(
                "Work",
                floatAutomatically: false,
                tileRules: RuleListOverride(rules: [Self.mail: true])
            )
        )
        let back = try JSONDecoder().decode(Profile.self, from: data)
        #expect(back.floatAutomatically == false)
        #expect(back.tileRules == RuleListOverride(rules: [Self.mail: true]))
    }

    @Test("the gui.json base resolves into the guess")
    func guiBaseResolves() throws {
        let core = try makeCore()
        try load(profile("Home"), into: core)
        #expect(guess(core).enabled)
        #expect(!guess(core).applies(to: Self.steam))
        #expect(guess(core).applies(to: Self.mail))
    }

    @Test("a profile's override wins over the base, and leaves with it")
    func profileOverrideResolves() throws {
        let core = try makeCore()
        try load(
            profile(
                "Work",
                floatAutomatically: false,
                tileRules: RuleListOverride(rules: [
                    Self.steam: nil, Self.mail: true,
                ])
            ),
            into: core
        )
        #expect(!guess(core).enabled)
        #expect(guess(core).tileRules == [Self.mail])
        try load(profile("Home"), into: core)
        #expect(guess(core).enabled)
        #expect(guess(core).tileRules == [Self.steam])
    }

    @Test("init.lua declares both, and a reload resets them")
    func luaDeclaresBoth() throws {
        let core = try makeCore(
            lua: """
                tile_rules = { "\(Self.steam)" }
                KiwiDesk.set_float_automatically(false)
                """
        )
        #expect(!guess(core).enabled)
        #expect(guess(core).tileRules == [Self.steam])
        try "-- nothing".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        #expect(guess(core).enabled)
        #expect(guess(core).tileRules.isEmpty)
    }

    @Test("the verb writes the base, under a profile's override")
    func verbWritesTheBase() throws {
        let core = try makeCore()
        try load(profile("Home"), into: core)
        #expect(
            core.execute("set_float_automatically", args: [.bool(false)])
                .isSuccess
        )
        #expect(!guess(core).enabled)
        #expect(guess(core).tileRules == [Self.steam])
        #expect(
            !core.execute("set_float_automatically", args: [.string("x")])
                .isSuccess
        )
    }

    @Test("the Lua seed carries both into gui.json")
    func seedCarriesBoth() throws {
        let core = try makeCore(
            lua: """
                tile_rules = { "\(Self.steam)" }
                KiwiDesk.set_float_automatically(false)
                """
        )
        let seed = core.guiConfigSeed()
        #expect(!seed.floatAutomatically)
        #expect(seed.tileRules == [Self.steam])
    }
}
