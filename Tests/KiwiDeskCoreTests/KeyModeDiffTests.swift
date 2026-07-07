import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Test helpers (per-file, AGENTS.md §5)

private func binding(
    combo: String,
    lua: String = "-- noop",
    label: String = ""
) -> KeyBinding {
    KeyBinding(
        combo: combo,
        lua: lua,
        kind: .custom,
        label: label
    )
}

private func mode(
    _ name: String,
    icon: String? = nil,
    combos: [(String, String)] = []
) -> KeyMode {
    KeyMode(
        name: name,
        icon: icon,
        bindings: combos.map { binding(combo: $0.0, lua: $0.1) }
    )
}

/// `KeyModeOverride.diff(base:edited:)` — the inverse of
/// `resolved(onto:)` used by the override-mode Shortcuts tab
/// (#55 phase 7). Deletion is intentionally NOT expressible
/// (O4 soft): a base row missing from `edited` is absent from
/// the diff and reappears on resolve.
@Suite("KeyModeOverride.diff — sparse inverse (#55 phase 7)")
struct KeyModeDiffTests {

    private let base: [KeyMode] = [
        mode(
            "default",
            combos: [
                ("alt+p", "load_profile"),
                ("alt+h", "focus_left"),
            ]
        ),
        mode("resize", icon: "🔧", combos: [("alt+l", "grow")]),
    ]

    // MARK: - Sparsity

    @Test("Identical edited set diffs to nil (fully inherited)")
    func identicalDiffsToNil() {
        #expect(
            KeyModeOverride.diff(base: base, edited: base)
                == nil
        )
    }

    @Test("One rebound combo produces a one-row override")
    func reboundComboIsSparse() throws {
        var edited = base
        edited[0].bindings[1] = binding(
            combo: "alt+h",
            lua: "CUSTOM"
        )
        let over = try #require(
            KeyModeOverride.diff(base: base, edited: edited)
        )
        #expect(over.modes.count == 1)
        #expect(over.modes[0].name == "default")
        #expect(over.modes[0].bindings.count == 1)
        #expect(over.modes[0].bindings[0].lua == "CUSTOM")
        // Untouched mode/icon carry nothing.
        #expect(over.modes[0].icon == nil)
    }

    @Test("Mode absent from base is carried whole")
    func newModeCarriedWhole() throws {
        let edited =
            base + [
                mode("nav", combos: [("alt+x", "noop")])
            ]
        let over = try #require(
            KeyModeOverride.diff(base: base, edited: edited)
        )
        #expect(over.modes.count == 1)
        #expect(over.modes[0].name == "nav")
    }

    @Test("Changed icon alone produces an icon-only override")
    func iconOnlyDiff() throws {
        var edited = base
        edited[1].icon = "📐"
        let over = try #require(
            KeyModeOverride.diff(base: base, edited: edited)
        )
        #expect(over.modes.count == 1)
        #expect(over.modes[0].name == "resize")
        #expect(over.modes[0].icon == "📐")
        #expect(over.modes[0].bindings.isEmpty)
    }

    @Test("kind/label-only differences are inherited (no diff)")
    func classifierUpgradeIsNotDivergence() {
        // The GUI import classifier upgrades display metadata
        // (.custom → .navigation, label filled) on the edited
        // copy while the stored base keeps the raw rows. Same
        // combo + lua = same action — an unchanged edit
        // session must never mint an override.
        var edited = base
        edited[0].bindings[1] = KeyBinding(
            combo: "alt+h",
            lua: "focus_left",
            kind: .navigation,
            label: "Focus left"
        )
        #expect(
            KeyModeOverride.diff(base: base, edited: edited)
                == nil
        )
    }

    @Test("Clearing a base icon is NOT expressible (reverts)")
    func iconClearNotExpressed() {
        // nil icon means inherit (`over.icon ?? base.icon`),
        // so an icon-only clear drops out of the diff entirely
        // — same delete-is-revert semantics as rows.
        var edited = base
        edited[1].icon = nil
        #expect(
            KeyModeOverride.diff(base: base, edited: edited)
                == nil
        )
    }

    @Test("Deleted base row is NOT expressed (O4 revert)")
    func deletionNotExpressed() {
        var edited = base
        edited[0].bindings.removeAll { $0.combo == "alt+h" }
        // Nothing else diverges → no override at all; the row
        // reappears on resolve (delete-inherited = revert).
        #expect(
            KeyModeOverride.diff(base: base, edited: edited)
                == nil
        )
    }

    // MARK: - Round-trip properties

    @Test("resolved(diff(base, edited)) reproduces edited")
    func resolveOfDiffReproducesEdited() throws {
        var edited = base
        edited[0].bindings[1] = binding(
            combo: "alt+h",
            lua: "CUSTOM"
        )
        edited[0].bindings.append(
            binding(combo: "alt+n", lua: "NEW")
        )
        edited[1].icon = "📐"
        let over = try #require(
            KeyModeOverride.diff(base: base, edited: edited)
        )
        #expect(over.resolved(onto: base) == edited)
    }

    @Test("diff(base, over.resolved(onto: base)) == over")
    func diffOfResolvedReproducesOverride() {
        let over = KeyModeOverride(
            modes: [
                mode("default", combos: [("alt+h", "CUSTOM")]),
                mode("nav", combos: [("alt+x", "noop")]),
            ]
        )
        let resolved = over.resolved(onto: base)
        #expect(
            KeyModeOverride.diff(base: base, edited: resolved)
                == over
        )
    }
}
