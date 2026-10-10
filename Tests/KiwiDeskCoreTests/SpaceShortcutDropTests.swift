import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A temporary Space's shortcuts go when it drops, and a held
/// Space's when its hold ends (#1827, ruling 2026-10-09) — the
/// base and every profile override, through the one drop path at
/// the retile — while a Space another arrangement declares keeps
/// its chords, which are #92's to surface. Replays the held-Space
/// desk.
@Suite("A gone Space's shortcuts (#1827)", .serialized)
@MainActor
struct SpaceShortcutDropTests {
    private let desk = HeldSpaceDesk()
    private let scratch = SpaceID(9)

    private func row(_ combo: String, _ verb: String, _ space: Int)
        -> KeyBinding
    {
        KeyBinding(
            combo: combo,
            lua: "KiwiDesk.\(verb)(\"\(space)\")",
            kind: .navigation,
            label: "\(verb) \(space)"
        )
    }

    /// `gui.json` with rows for Spaces 1, 5 and 9, and `solo` with
    /// its own row for 9 and a tombstone over the base's ⌃⌥9.
    private func seedShortcuts(_ core: KiwiCore) throws {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    row("control+option+1", "focus_space", 1),
                    row("control+option+5", "focus_space", 5),
                    row("control+option+9", "focus_space", 9),
                    row("control+option+shift+9", "move_to_space", 9),
                ]
            )
        ]
        try core.guiConfigStore.save(config)
        var solo = try core.profiles.read(name: "solo")
        solo.layers = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [
                        row(
                            "control+option+command+9",
                            "move_to_space_and_follow",
                            9
                        )
                    ]
                )
            ],
            removed: [KeyLayer.defaultName: ["control+option+9"]]
        )
        try core.profiles.write(solo)
    }

    private func baseCombos(_ core: KiwiCore) -> [String] {
        core.guiConfigStore.load()?.layers.first?.bindings.map(\.combo)
            ?? []
    }

    /// Space 9 made by a move, then emptied and left: it drops.
    private func dropScratch(_ core: KiwiCore) {
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

    @Test("a dropped temporary Space takes its chords, everywhere")
    func temporaryDropTakesItsChords() throws {
        let core = try desk.docked()
        try seedShortcuts(core)
        var told: [Set<SpaceID>] = []
        core.onShortcutsDropped = { told.append($0) }
        dropScratch(core)
        #expect(core.state.workspaces[scratch] == nil)
        #expect(
            baseCombos(core) == ["control+option+1", "control+option+5"]
        )
        // Its own row and the tombstone over the gone base row go,
        // so the profile has nothing left to override.
        #expect(try core.profiles.read(name: "solo").layers == nil)
        #expect(told == [[scratch]], "an open draft is never told")
    }

    @Test("a Space another arrangement declares keeps its chords")
    func declaredElsewhereKeeps() throws {
        let core = try desk.docked()
        try seedShortcuts(core)
        try core.profiles.write(
            desk.profile(
                "studio",
                screens: [desk.builtIn.fingerprint],
                spaces: [SpaceID(1), scratch]
            )
        )
        dropScratch(core)
        #expect(core.state.workspaces[scratch] == nil)
        #expect(baseCombos(core).contains("control+option+9"))
    }

    @Test("a held Space's chords go when its hold ends")
    func heldHoldEndTakesItsChords() throws {
        let core = try desk.docked()
        try seedShortcuts(core)
        // Unplugged: the DELL's 3 and 4 are held as 5 and 6.
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(core.state.heldSpaces[SpaceID(5)] != nil)
        #expect(baseCombos(core).contains("control+option+5"))
        // Replugged: they go home and the held numbers retire.
        core.handle(.displaysChanged([desk.builtIn, desk.dell]))
        #expect(core.state.workspaces[SpaceID(5)] == nil)
        #expect(!baseCombos(core).contains("control+option+5"))
        #expect(baseCombos(core).contains("control+option+1"))
    }
}
