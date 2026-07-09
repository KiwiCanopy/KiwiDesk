import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The forget-proof net over the #91 mirror: Core's
/// `DefaultKeybindings` authors the same Lua and canonical
/// labels the GUI's `KeybindingCatalog` generates — byte for
/// byte, or the import classifier would demote seeded rows to
/// Custom (#4). The test discovers rows by iterating the seed
/// output (never a hand-enumerated list), so a new seeded row
/// that the catalog does not back fails here automatically
/// (see .claude/rules/parity-tests.md).
///
/// Scope: the net is directional — seed ⊆ catalog. It pins that
/// every *seeded* row round-trips, not that the two files can
/// never drift on a catalog-only shape (e.g. a
/// `move_to_space_and_follow` label the seed never emits). That
/// is the right guarantee for #91 — seeded rows must not demote
/// — but do not read it as "the label lists can never diverge."
@Suite("Default seed ↔ catalog parity (#91)")
@MainActor
struct DefaultSeedCatalogParityTests {
    private let spaces = [
        SpaceID("1"), SpaceID("mail"), SpaceID("a b"),
    ]
    private let step = 37

    /// lua → canonical label for everything the catalog can
    /// author for these spaces and this step.
    private var catalog: [String: String] {
        var map: [String: String] = [:]
        let groups = KeybindingCatalog.navigationGroups(
            spaces: spaces
        )
        for group in groups {
            for command in group.commands {
                map[command.lua] = command.label
            }
        }
        for command in KeybindingCatalog.resizeAndFloat(
            step: step
        ) {
            map[command.lua] = command.label
        }
        return map
    }

    @Test("every seeded row matches a catalog command exactly")
    func seededRowsMatchCatalog() {
        let seeded = DefaultKeybindings.bindings(
            spaces: spaces,
            resizeStep: step
        )
        let map = catalog
        #expect(!seeded.isEmpty)
        for row in seeded {
            let catalogLabel = map[row.lua] ?? "MISSING"
            #expect(
                map[row.lua] == row.label,
                "drifted: \(row.lua) → \(catalogLabel)"
            )
        }
    }

    /// The end-to-end guarantee behind the byte-for-byte rule:
    /// a seeded row round-tripped as `.custom` (as an import
    /// would deliver it) classifies back to `.navigation`,
    /// never Custom.
    @Test("seeded rows survive the import classifier")
    func seededRowsClassify() {
        var config = GuiConfig()
        config.spaces = spaces
        config.settings.resizeStep = CGFloat(step)
        var mode = KeyMode.defaultMode
        mode.bindings = DefaultKeybindings.bindings(
            spaces: spaces,
            resizeStep: step
        ).map { row in
            KeyBinding(
                combo: row.combo,
                lua: row.lua,
                kind: .custom,
                label: ""
            )
        }
        config.modes = [mode]
        KeybindingImportClassifier.classify(&config)
        for row in config.modes[0].bindings {
            #expect(
                row.kind == .navigation,
                "demoted to \(row.kind): \(row.lua)"
            )
        }
    }
}
