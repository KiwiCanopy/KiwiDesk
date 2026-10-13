import Foundation
import Testing

@testable import KiwiDeskCore

/// The rows a release added after the first-run seed reach an
/// install that predates them, once, where the action is unbound
/// and the chord free (#2211).
@Suite("Default shortcuts are topped up by generation", .serialized)
@MainActor
struct DefaultShortcutGenerationTests {
    private let back = "KiwiDesk.focus_space_back()"
    private let forward = "KiwiDesk.focus_space_forward()"
    private let previous = "KiwiDesk.focus_space_previous()"
    private let next = "KiwiDesk.focus_space_next()"
    /// Generations 2 and 3: 3.0.0's layout keys (#453, #762) and
    /// Jump to window (#1875).
    private let layoutKeys = [
        "KiwiDesk.cycle_mode()", "KiwiDesk.cycle_mode(\"prev\")",
        "KiwiDesk.show_layout_picker()",
        "KiwiDesk.show_jump_to_window()",
    ]

    /// 2.2.0's swap, on the ⌃⌥⌘ arrows the Space steps now take.
    private var swapOnSteps: [KeyBinding] {
        ["left", "right"].map {
            KeyBinding(
                combo: "control+option+command+\($0)",
                lua: "KiwiDesk.swap(\"\($0)\")",
                kind: .navigation
            )
        }
    }

    @Test("A 2.2.0 keymap gets the history pair, not the taken steps")
    func takenStepsAreSkipped() {
        let rows = DefaultKeybindings.generationTopUp(
            existing: swapOnSteps,
            above: 0
        )
        #expect(rows.map(\.lua) == [back, forward] + layoutKeys)
    }

    @Test("Free chords get every generation's rows")
    func freeChordsGetAll() {
        let rows = DefaultKeybindings.generationTopUp(
            existing: [],
            above: 0
        )
        #expect(
            Set(rows.map(\.lua))
                == Set([back, forward, previous, next] + layoutKeys)
        )
    }

    @Test("An action bound elsewhere is left alone")
    func boundActionIsSkipped() {
        let mine = KeyBinding(
            combo: "control+option+b",
            lua: back,
            kind: .navigation
        )
        let rows = DefaultKeybindings.generationTopUp(
            existing: [mine],
            above: 0
        )
        #expect(!rows.map(\.lua).contains(back))
        #expect(rows.map(\.lua).contains(forward))
    }

    @Test("Nothing past the newest generation")
    func newestOffersNothing() {
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [],
                above: DefaultKeybindings.newestGeneration
            ).isEmpty
        )
    }

    /// A fresh seed carries every generation, so it tops up
    /// nothing; a generation row missing from the seed would reach
    /// upgraders and never a new install.
    @Test("The seed carries every generation's rows")
    func seedCarriesEveryGeneration() {
        let seed = DefaultKeybindings.bindings(
            spaces: [SpaceID("1")],
            resizeStep: 10
        )
        for number in 1...DefaultKeybindings.newestGeneration {
            for row in DefaultKeybindings.rows(ofGeneration: number) {
                #expect(
                    seed.contains {
                        $0.lua == row.lua && $0.combo == row.combo
                    },
                    Comment(rawValue: "seed lacks \(row.lua)")
                )
            }
        }
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: seed,
                above: 0
            ).isEmpty
        )
    }

    /// The actions the 2.2.0 seed bound, its digit and Desktop
    /// families aside, which their own top-ups own. Frozen: a later
    /// seed row joins a generation, never this list.
    private let seededBeforeGenerations: Set<String> = [
        "KiwiDesk.focus(\"left\")", "KiwiDesk.focus(\"down\")",
        "KiwiDesk.focus(\"up\")", "KiwiDesk.focus(\"right\")",
        "KiwiDesk.swap(\"left\")", "KiwiDesk.swap(\"down\")",
        "KiwiDesk.swap(\"up\")", "KiwiDesk.swap(\"right\")",
        "KiwiDesk.resize(\"x\", 10)", "KiwiDesk.resize(\"x\", -10)",
        "KiwiDesk.resize(\"y\", 10)", "KiwiDesk.resize(\"y\", -10)",
        "KiwiDesk.toggle_floating()", "KiwiDesk.toggle_sticky()",
        "KiwiDesk.toggle_display_sticky()",
        "KiwiDesk.show_shortcuts()", "KiwiDesk.open_settings()",
    ]

    /// The direction a release forgets: a seed row added with no
    /// generation reaches new installs alone, and reds here.
    @Test("Every seed row is the 2.2.0 baseline or a generation's")
    func everySeedRowHasAGeneration() {
        let seed = DefaultKeybindings.bindings(
            spaces: [SpaceID("1")],
            resizeStep: 10
        )
        let families = [
            "KiwiDesk.focus_space(", "KiwiDesk.move_to_space(",
            "KiwiDesk.move_to_space_and_follow(",
            "KiwiDesk.focus_desktop(",
        ]
        let actions = Set(
            seed.map(\.lua).filter { lua in
                !families.contains { lua.hasPrefix($0) }
            }
        )
        let generations = Set(
            (1...DefaultKeybindings.newestGeneration).flatMap {
                DefaultKeybindings.rows(ofGeneration: $0).map(\.lua)
            }
        )
        #expect(!actions.isEmpty)
        #expect(actions == seededBeforeGenerations.union(generations))
    }

    private final class Mark { var value = 0 }

    private func makeCore(
        mark: Mark,
        base: [KeyBinding]
    ) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-generation-topup-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings = base
        try core.guiConfigStore.save(config)
        core.desktopMemory.readDefaultsGeneration = { mark.value }
        core.desktopMemory.writeDefaultsGeneration = { mark.value = $0 }
        return core
    }

    private func baseLua(_ core: KiwiCore) -> [String] {
        (core.persistedGuiConfig()?.layers.first { $0.isDefault }?
            .bindings ?? []).map(\.lua)
    }

    @Test("An update adds the rows once; a deleted one stays gone")
    func offeredOnce() throws {
        let mark = Mark()
        let core = try makeCore(mark: mark, base: swapOnSteps)
        core.topUpGenerationShortcuts()
        #expect(baseLua(core).contains(back))
        #expect(baseLua(core).contains(forward))
        #expect(!baseLua(core).contains(next))
        #expect(mark.value == DefaultKeybindings.newestGeneration)

        var config = try #require(core.persistedGuiConfig())
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings.removeAll { $0.lua == back }
        try core.guiConfigStore.save(config)

        core.topUpGenerationShortcuts()
        #expect(!baseLua(core).contains(back))
    }

    /// The mark vouches for rows in gui.json, so a discarded or
    /// replaced sidecar — a restored backup, a reset — is offered
    /// every generation again.
    @Test("Discarding gui.json resets the generation mark")
    func discardClearsTheMark() throws {
        let mark = Mark()
        let core = try makeCore(mark: mark, base: swapOnSteps)
        core.topUpGenerationShortcuts()
        #expect(mark.value == DefaultKeybindings.newestGeneration)
        _ = core.discardArtifacts(
            [.guiConfig],
            reason: "test",
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        #expect(mark.value == 0)
    }

    @Test("A profile's own row for the action counts as bound")
    func profileRowCountsAsBound() throws {
        let mark = Mark()
        let core = try makeCore(mark: mark, base: swapOnSteps)
        var profile = Profile(
            name: "Work",
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
        profile.layers = KeyLayerOverride(layers: [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "control+option+b",
                        lua: back,
                        kind: .navigation
                    )
                ]
            )
        ])
        try core.profiles.write(profile)
        core.topUpGenerationShortcuts()
        #expect(!baseLua(core).contains(back))
        #expect(baseLua(core).contains(forward))
    }

    /// The guard's own case: a sidecar beside an init.lua that owns
    /// the managed vocabulary.
    @Test("A setup the GUI does not manage keeps its mark")
    func luaOwnedKeepsTheMark() throws {
        let mark = Mark()
        let core = try makeCore(mark: mark, base: swapOnSteps)
        try "KiwiDesk.bind(\"cmd+1\", function() end)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        #expect(!core.isGuiManaged)
        core.topUpGenerationShortcuts()
        #expect(mark.value == 0)
        #expect(!baseLua(core).contains(back))
    }
}
