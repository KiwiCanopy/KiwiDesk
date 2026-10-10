import Foundation
import Testing

@testable import KiwiDeskCore

/// The drop is owed where a Space ENDS and paid at the next retile
/// (#1827 review): a held Space that merely lost its workspace is
/// not gone, a number still owed is not minted again, and the
/// trim keeps a profile's own layer and an icon override.
@Suite("A gone Space's shortcuts, owed (#1827)", .serialized)
@MainActor
struct SpaceShortcutDropOwedTests {
    private let desk = HeldSpaceDesk()

    private func row(_ combo: String, _ space: Int) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: "KiwiDesk.focus_space(\"\(space)\")",
            kind: .navigation,
            label: "focus_space \(space)"
        )
    }

    private func baseCombos(_ core: KiwiCore) -> [String] {
        core.guiConfigStore.load()?.layers.first?.bindings.map(\.combo)
            ?? []
    }

    /// Space 9 made by a move, then emptied and left: it drops.
    private func dropScratch(_ core: KiwiCore) {
        let scratch = SpaceID(9)
        core.execute(
            "move_to_space",
            args: [.string(scratch.raw), .number(13)]
        )
        core.execute(
            "pin_space_to_display",
            args: [.string(scratch.raw), .string(desk.builtIn.fingerprint)]
        )
        core.retile()
        core.state.workspaces.activate(SpaceID(1))
        core.state.workspaces.add(WindowID(13), to: SpaceID(1))
        core.retile()
    }

    @Test("a chord only another profile holds is still owed")
    func otherProfileChordIsOwed() throws {
        let core = try desk.docked()
        try core.guiConfigStore.save(GuiConfig())
        var studio = desk.profile(
            "studio",
            screens: [desk.builtIn.fingerprint],
            spaces: [SpaceID(1)]
        )
        studio.layers = KeyLayerOverride(
            layers: [
                KeyLayer(name: "Studio", bindings: [row("f13", 9)])
            ]
        )
        try core.profiles.write(studio)
        dropScratch(core)
        #expect(core.state.workspaces[SpaceID(9)] == nil)
        let kept =
            try core.profiles.read(name: "studio").layers?
            .layers.flatMap(\.bindings) ?? []
        #expect(kept.isEmpty)
    }

    @Test("a number live again keeps its chords")
    func liveAgainKeeps() throws {
        let core = try desk.docked()
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [row("control+option+9", 9)]
            )
        ]
        try core.guiConfigStore.save(config)
        // Space 9 is live and no arrangement declares it.
        core.execute("move_to_space", args: [.string("9"), .number(13)])
        #expect(core.state.workspaces[SpaceID(9)] != nil)
        core.state.owedShortcutDrops = [SpaceID(9)]
        core.retile()
        #expect(core.state.owedShortcutDrops.isEmpty)
        #expect(baseCombos(core) == ["control+option+9"])
    }

    @Test("an emptied hold with no workspace owes its chords")
    func emptiedHoldOwes() throws {
        let core = try desk.docked()
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [row("control+option+5", 5)]
            )
        ]
        try core.guiConfigStore.save(config)
        let away = WindowID(22)
        core.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: 3,
            appName: "Away",
            appBundleID: "app.away",
            nativeSpace: 4
        )
        core.state.rememberedSpaces[away] = .departed(SpaceID(3))
        core.handle(.displaysChanged([desk.builtIn]))
        let held = SpaceID(5)
        core.state.workspaces.removeSpace(held)
        core.retile()
        #expect(core.state.heldSpaces[held] != nil)
        // Its last remembered window goes: the hold ends with no
        // Space to forward, so only the door owes the drop.
        core.state.awayWindows[away] = nil
        core.state.rememberedSpaces[away] = nil
        core.retile()
        #expect(core.state.heldSpaces[held] == nil)
        core.retile()
        #expect(!baseCombos(core).contains("control+option+5"))
    }

    @Test("a number whose drop is owed is never minted")
    func owedNumberIsTaken() {
        let core = makeTestCore()
        let free = core.mintedSpaceNumber()
        core.state.owedShortcutDrops = [free]
        #expect(core.mintedSpaceNumber() != free)
    }

    @Test("a held Space that lost its workspace keeps its chords")
    func stillHeldKeepsItsChords() throws {
        let core = try desk.docked()
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [row("control+option+5", 5)]
            )
        ]
        try core.guiConfigStore.save(config)
        // An up away window returning to the DELL's 3, which the
        // hold carries to 5: it keeps the hold alive (#1507).
        let away = WindowID(22)
        core.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: 3,
            appName: "Away",
            appBundleID: "app.away",
            nativeSpace: 4
        )
        core.state.rememberedSpaces[away] = .departed(SpaceID(3))
        core.handle(.displaysChanged([desk.builtIn]))
        let held = SpaceID(5)
        #expect(core.state.heldSpaces[held] != nil)
        // The hold outlives its workspace (a remembered member):
        // nothing ended, so nothing is owed.
        core.state.workspaces.removeSpace(held)
        core.retile()
        core.retile()
        #expect(core.state.heldSpaces[held] != nil)
        #expect(baseCombos(core).contains("control+option+5"))
    }

    @Test("the trim keeps a profile's own layer and an icon override")
    func trimKeepsOwnLayers() {
        let gone: Set<SpaceID> = [SpaceID(12)]
        let override = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [row("control+option+command+2", 12)]
                ),
                KeyLayer(name: "Scratch", bindings: [row("f13", 12)]),
                KeyLayer(
                    name: "Work",
                    icon: "hammer",
                    bindings: [row("f14", 12)]
                ),
            ]
        )
        let trimmed = override.removingRows(
            naming: gone,
            baseRemoved: [:],
            baseLayers: [KeyLayer.defaultName, "Work"]
        )
        let names = trimmed?.layers.map(\.name) ?? []
        #expect(names == ["Scratch", "Work"])
        #expect(trimmed?.layers.allSatisfy(\.bindings.isEmpty) == true)
    }
}
