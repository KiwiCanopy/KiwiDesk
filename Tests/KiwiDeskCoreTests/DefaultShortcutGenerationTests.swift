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
    /// Generations 2 to 7: 3.0.0's layout keys (#453, #762), the
    /// window switcher (#1875), KiwiVision (#2103), 3.1.0's Reset
    /// sizes (#2303), the bars' shortcuts (#761) and Maximize
    /// (#2448).
    private let layoutKeys = [
        "KiwiDesk.cycle_mode()", "KiwiDesk.cycle_mode(\"prev\")",
        "kiwihub.show(\"view\")",
        "kiwihub.show(\"windows\")",
        "kiwivision.toggle()",
        "KiwiDesk.reset_layout_sizing()",
        "space_bar.toggle_reveal()", "app_bar.toggle_reveal()",
        "KiwiDesk.toggle_maximized()",
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
            above: 0,
            base: .standard
        )
        #expect(rows.map(\.lua) == [back, forward] + layoutKeys)
    }

    @Test("KiwiVision is generation 4, alone")
    func kiwiVisionGeneration() {
        #expect(
            DefaultKeybindings.rows(ofGeneration: 4)
                == [DefaultKeybindings.kiwiVisionRow()]
        )
    }

    @Test("Free chords get every generation's rows")
    func freeChordsGetAll() {
        let rows = DefaultKeybindings.generationTopUp(
            existing: [],
            above: 0,
            base: .standard
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
            above: 0,
            base: .standard
        )
        #expect(!rows.map(\.lua).contains(back))
        #expect(rows.map(\.lua).contains(forward))
    }

    @Test("Nothing past the newest generation")
    func newestOffersNothing() {
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [],
                above: DefaultKeybindings.newestGeneration,
                base: .standard
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
            resizeStep: 10,
            base: .standard
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
                above: 0,
                base: .standard
            ).isEmpty
        )
    }

    /// The actions the 2.2.0 seed bound, its digit and Desktop
    /// families aside, which their own top-ups own. Frozen: a later
    /// seed row joins a generation, never this list — save a
    /// spelling a migration renamed, which the stored row now
    /// carries (#2265).
    private let seededBeforeGenerations: Set<String> = [
        "KiwiDesk.focus(\"left\")", "KiwiDesk.focus(\"down\")",
        "KiwiDesk.focus(\"up\")", "KiwiDesk.focus(\"right\")",
        "KiwiDesk.swap(\"left\")", "KiwiDesk.swap(\"down\")",
        "KiwiDesk.swap(\"up\")", "KiwiDesk.swap(\"right\")",
        "KiwiDesk.resize(\"x\", 10)", "KiwiDesk.resize(\"x\", -10)",
        "KiwiDesk.resize(\"y\", 10)", "KiwiDesk.resize(\"y\", -10)",
        "KiwiDesk.toggle_floating()", "KiwiDesk.toggle_sticky()",
        "KiwiDesk.toggle_display_sticky()",
        "kiwihub.show(\"shortcuts\")", "KiwiDesk.open_settings()",
    ]

    /// The direction a release forgets: a seed row added with no
    /// generation reaches new installs alone, and reds here.
    @Test("Every seed row is the 2.2.0 baseline or a generation's")
    func everySeedRowHasAGeneration() {
        let seed = DefaultKeybindings.bindings(
            spaces: [SpaceID("1")],
            resizeStep: 10,
            base: .standard
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

    private func offered(_ core: KiwiCore) -> ShortcutOffer {
        core.persistedGuiConfig()?.shortcutOffer ?? ShortcutOffer()
    }

    private func makeCore(
        base: [KeyBinding]
    ) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-generation-topup-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings = base
        try core.guiConfigStore.save(config)
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        return core
    }

    private func baseLua(_ core: KiwiCore) -> [String] {
        (core.persistedGuiConfig()?.layers.first { $0.isDefault }?
            .bindings ?? []).map(\.lua)
    }

    @Test("An update adds the rows once; a deleted one stays gone")
    func offeredOnce() throws {
        let core = try makeCore(base: swapOnSteps)
        core.topUpGenerationShortcuts()
        #expect(baseLua(core).contains(back))
        #expect(baseLua(core).contains(forward))
        #expect(!baseLua(core).contains(next))
        #expect(
            offered(core).generation == DefaultKeybindings.newestGeneration
        )

        var config = try #require(core.persistedGuiConfig())
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings.removeAll { $0.lua == back }
        try core.guiConfigStore.save(config)

        core.topUpGenerationShortcuts()
        #expect(!baseLua(core).contains(back))
    }

    /// The offer lives in gui.json, so a discarded sidecar takes it
    /// along; the session's copy and this Mac's pre-#2324 marks go
    /// with it, or a reset would never be offered a generation.
    @Test("Discarding gui.json resets the generation offer")
    func discardClearsTheMark() throws {
        let core = try makeCore(base: swapOnSteps)
        var cleared = 0
        core.desktopMemory.clearLegacyShortcutOffer = { cleared += 1 }
        core.topUpGenerationShortcuts()
        #expect(
            offered(core).generation == DefaultKeybindings.newestGeneration
        )
        _ = core.discardArtifacts(
            [.guiConfig],
            reason: "test",
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        #expect(cleared == 2)
        #expect(core.desktopMemory.knownShortcutOffer == nil)
    }

    @Test("A profile's own row for the action counts as bound")
    func profileRowCountsAsBound() throws {
        let core = try makeCore(base: swapOnSteps)
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
        let core = try makeCore(base: swapOnSteps)
        try "KiwiDesk.bind(\"cmd+1\", function() end)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        #expect(!core.isGuiManaged)
        core.topUpGenerationShortcuts()
        #expect(offered(core).generation == 0)
        #expect(!baseLua(core).contains(back))
    }
}
