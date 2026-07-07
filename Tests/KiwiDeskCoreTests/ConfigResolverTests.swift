import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Test helpers (per-file, AGENTS.md §5)

private func binding(
    combo: String,
    lua: String = "-- noop"
) -> KeyBinding {
    KeyBinding(combo: combo, lua: lua, kind: .custom, label: "")
}

private func mode(
    _ name: String,
    combos: [(String, String)] = []
) -> KeyMode {
    KeyMode(
        name: name,
        bindings: combos.map { binding(combo: $0.0, lua: $0.1) }
    )
}

// MARK: - ConfigResolver tests

@Suite("ConfigResolver — thin modes resolver (#55 O1)")
struct ConfigResolverTests {

    private let base: [KeyMode] = [
        mode("default", combos: [("alt+h", "base")])
    ]

    @Test("nil profile returns base unchanged")
    func nilProfileReturnsBase() {
        let result = ConfigResolver.resolvedModes(
            base: base,
            profile: nil
        )
        #expect(result == base)
    }

    @Test("Empty override returns base unchanged")
    func emptyOverrideReturnsBase() {
        let result = ConfigResolver.resolvedModes(
            base: base,
            profile: KeyModeOverride()
        )
        #expect(result == base)
    }

    @Test("Present override produces merged result")
    func presentOverrideMerges() {
        let over = KeyModeOverride(
            modes: [
                mode("default", combos: [("alt+h", "override")])
            ]
        )
        let result = ConfigResolver.resolvedModes(
            base: base,
            profile: over
        )
        let lua = result.first?.bindings
            .first { $0.combo == "alt+h" }?.lua
        #expect(lua == "override")
    }

    @Test("Empty base + profile modes returns profile modes")
    func emptyBasePlusProfile() {
        let over = KeyModeOverride(
            modes: [mode("nav", combos: [("alt+x", "noop")])]
        )
        let result = ConfigResolver.resolvedModes(
            base: [],
            profile: over
        )
        #expect(result.count == 1)
        #expect(result[0].name == "nav")
    }
}
