import Foundation
import Testing

@testable import KiwiDeskCore

/// The "Shortcuts use" switch (#2460): every row the mapping covers
/// moves in every layer, a held target keeps its row, the base moves
/// with the rows, and `⌃⌥` undoes `✦`.
@Suite("Shortcut base switch (#2460)")
struct ShortcutBaseSwitchTests {
    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation, label: "")
    }

    private func config(_ layers: [String: [KeyBinding]]) -> GuiConfig {
        var config = GuiConfig()
        config.layers = layers.sorted { $0.key < $1.key }.map {
            KeyLayer(name: $0.key, bindings: $0.value)
        }
        return config
    }

    private func combos(_ config: GuiConfig, _ layer: String) -> [String] {
        config.layers.first { $0.name == layer }?.bindings.map(\.combo)
            ?? []
    }

    private var seeded: [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: ["1", "2", "3"].map { SpaceID($0) },
            resizeStep: 1,
            base: .standard
        )
            + (1...3).compactMap {
                DefaultKeybindings.desktopRow($0, base: .standard)
            }
    }

    @Test("the seed moves onto ✦ whole, the size tier stays")
    func seedMoves() {
        var config = config([KeyLayer.defaultName: seeded])
        #expect(
            ShortcutBaseSwitch.kept(config.layers[0], onto: .hyper).isEmpty
        )
        ShortcutBaseSwitch.apply(.hyper, to: &config)
        #expect(config.shortcutBase == .hyper)
        let moved = combos(config, KeyLayer.defaultName)
        #expect(
            moved == seeded.map { ShortcutBase.hyper.rebased($0).combo }
        )
        #expect(moved.contains("hyper+f"))
        #expect(moved.contains("hyper+option+3"))
        #expect(moved.contains("option+command+2"))
        #expect(!moved.contains { $0.hasPrefix("control+option") })
    }

    @Test("every layer moves, each judged on its own rows")
    func everyLayerMoves() {
        var config = config([
            KeyLayer.defaultName: [row("control+option+f", "a()")],
            "work": [
                row("control+option+f", "b()"),
                row("f", "holder()"),
            ],
        ])
        let kept = config.layers.flatMap {
            ShortcutBaseSwitch.kept($0, onto: .hyper)
        }
        ShortcutBaseSwitch.apply(.hyper, to: &config)
        #expect(combos(config, KeyLayer.defaultName) == ["hyper+f"])
        #expect(combos(config, "work") == ["control+option+f", "f"])
        #expect(kept.map(\.layer) == ["work"])
        #expect(kept.first?.holder.lua == "holder()")
        #expect(kept.first?.target == "hyper+f")
    }

    /// `✦F` registers as a bare F while Hyper is held, so a row on
    /// bare F holds it, as the conflict check reads it.
    @Test("a held target keeps its row and names the holder")
    func heldTargetStays() {
        let rows = [row("control+option+s", "s()"), row("s", "mine()")]
        let layer = KeyLayer(name: KeyLayer.defaultName, bindings: rows)
        #expect(
            ShortcutBaseSwitch.kept(layer, onto: .hyper).map(\.holder.lua)
                == ["mine()"]
        )
    }

    @Test("a row rebound off ⌃⌥ stays where the user put it")
    func reboundRowStays() {
        var config = config([
            KeyLayer.defaultName: [
                row("control+command+f", "a()"),
                row("hyper+shift+command+3", "b()"),
            ]
        ])
        ShortcutBaseSwitch.apply(.hyper, to: &config)
        #expect(
            combos(config, KeyLayer.defaultName)
                == ["control+command+f", "hyper+shift+command+3"]
        )
    }

    @Test("⌃⌥ moves back what ✦ moved, and the base with it")
    func backUndoes() {
        var config = config([KeyLayer.defaultName: seeded])
        ShortcutBaseSwitch.apply(.hyper, to: &config)
        ShortcutBaseSwitch.apply(.standard, to: &config)
        #expect(config.shortcutBase == .standard)
        #expect(combos(config, KeyLayer.defaultName) == seeded.map(\.combo))
    }

    @Test("gui.json carries the base; absence is the seed's")
    func storedShape() throws {
        var config = GuiConfig()
        config.shortcutBase = .hyper
        let data = try JSONEncoder().encode(config)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"shortcut_base\":\"hyper\""))
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.shortcutBase == .hyper)
        let bare = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data("{}".utf8)
        )
        #expect(bare.shortcutBase == .standard)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                GuiConfig.self,
                from: Data(#"{"shortcut_base":"meta"}"#.utf8)
            )
        }
    }

    @Test("the Desktop top-up writes on the base, a held chord skipped")
    func desktopTopUpFollowsTheBase() {
        let rows = DefaultKeybindings.desktopTopUp(
            existing: [],
            desktops: [1, 2],
            above: 0,
            base: .hyper
        )
        #expect(rows.map(\.combo) == ["hyper+option+1", "hyper+option+2"])
        let taken = DefaultKeybindings.desktopTopUp(
            existing: [row("hyper+option+1", "hs.x()")],
            desktops: [1, 2],
            above: 0,
            base: .hyper
        )
        #expect(taken.map(\.lua) == ["KiwiDesk.focus_desktop(2)"])
    }

    @Test("a moved row's change is the switch's, any other is not")
    func explainsTheMove() {
        let explains = ShortcutBaseSwitch.explains
        #expect(explains("control+option+f", "hyper+f", .hyper))
        #expect(
            explains(
                "hyper+option+3",
                "control+option+shift+command+3",
                .standard
            )
        )
        #expect(!explains("control+option+f", "hyper+g", .hyper))
        #expect(!explains("control+option+f", "hyper+f", .standard))
        #expect(!explains(nil, "hyper+f", .hyper))
    }

    /// An action already on ✦ beside its ⌃⌥ row would hold two
    /// chords after the move; the switch ends in the one dedupe.
    @Test("the switch leaves one chord per action")
    func endsInTheDedupe() {
        var config = config([
            KeyLayer.defaultName: [
                row("control+option+f", "KiwiDesk.toggle_floating()"),
                row("hyper+g", "KiwiDesk.toggle_floating()"),
            ]
        ])
        ShortcutBaseSwitch.apply(.hyper, to: &config)
        #expect(combos(config, KeyLayer.defaultName).count == 1)
    }
}
