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
        #expect(rows.map(\.lua) == [back, forward])
    }

    @Test("Free chords get all four rows")
    func freeChordsGetAll() {
        let rows = DefaultKeybindings.generationTopUp(
            existing: [],
            above: 0
        )
        #expect(Set(rows.map(\.lua)) == [back, forward, previous, next])
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

    @Test("A setup the GUI does not manage keeps its mark")
    func luaOwnedKeepsTheMark() throws {
        let mark = Mark()
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-generation-lua-\(UUID().uuidString)"
                )
        )
        core.desktopMemory.readDefaultsGeneration = { mark.value }
        core.desktopMemory.writeDefaultsGeneration = { mark.value = $0 }
        core.topUpGenerationShortcuts()
        #expect(mark.value == 0)
    }
}
