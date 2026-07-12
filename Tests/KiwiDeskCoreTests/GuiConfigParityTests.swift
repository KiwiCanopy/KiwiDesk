import Foundation
import Testing

@testable import KiwiDeskCore

/// The GuiConfig global field list is hand-mirrored in four
/// places — manual `CodingKeys`/decode/encode, the GUI's
/// `globalsChanged` comparison, `guiConfigSeed`, and
/// `applyStructuredRules` — which crossed the AGENTS.md §5
/// two-mirror threshold with `track_advanced` (#181 review).
/// Swift reflection cannot inspect those code paths, so the
/// net has two layers: a field-list tripwire (adding a stored
/// property fails here until every mirror site is visited) and
/// a rebuilt-from-JSON round-trip over every sidecar global (a
/// forgotten encode/decode line fails there).
@Suite("GuiConfig mirror parity (#181 review)")
struct GuiConfigParityTests {
    @Test("Field-list tripwire: visit every mirror site")
    func fieldTripwire() {
        let fields = Set(
            Mirror(reflecting: GuiConfig())
                .children.compactMap(\.label)
        )
        // Adding a field? Decide global vs profile-scoped
        // (#36), then update: CodingKeys + decode + encode
        // (GuiConfig.swift, globals only), `globalsChanged`
        // (SettingsModel+Profiles), `guiConfigSeed`,
        // `applyStructuredRules` / `applyProfileScopedState`,
        // the round-trip below — and only then this list.
        #expect(
            fields == [
                "settings", "spaces", "spaceModes", "appRules",
                "spacePins", "mainSpaces", "fallbackSpace",
                "floatRules", "profileBindings",
                "trackAdvanced", "modes",
            ]
        )
    }

    @Test("Every sidecar global round-trips non-default")
    func globalsRoundTrip() throws {
        var config = GuiConfig()
        config.spaces = [SpaceID("a"), SpaceID("b")]
        config.appRules = ["Mail": SpaceID("a")]
        config.floatRules = ["Calculator"]
        config.profileBindings = [2: "Studio"]
        config.trackAdvanced = true
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "-- noop",
                        kind: .custom,
                        label: "t"
                    )
                ]
            )
        ]
        let back = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(back.spaces == config.spaces)
        #expect(back.appRules == config.appRules)
        #expect(back.floatRules == config.floatRules)
        #expect(back.profileBindings == config.profileBindings)
        #expect(back.trackAdvanced == config.trackAdvanced)
        #expect(back.modes == config.modes)
        // Profile-scoped fields deliberately do NOT ride the
        // sidecar (#36) — they come back default.
        #expect(back.settings == TilingSettings())
        #expect(back.spaceModes.isEmpty)
        #expect(back.spacePins.isEmpty)
        #expect(back.mainSpaces.isEmpty)
        #expect(back.fallbackSpace == nil)
    }
}
