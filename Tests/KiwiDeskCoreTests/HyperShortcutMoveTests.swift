import Foundation
import Testing

@testable import KiwiDeskCore

/// The Hyper move offer's letter lines (#1870): read off the seed,
/// seeded rows ticked, a rebound row on `⌃⌥` listed unticked, one
/// rebound off it left out, a taken Hyper chord refusing, and
/// KiwiHub's sides moving with Open Settings or not at all.
@Suite("Hyper move offer: the letter lines")
struct HyperShortcutMoveTests {
    private func seedLayer() -> [KeyBinding] {
        DefaultKeybindings.bindings(spaces: [SpaceID(1)], resizeStep: 50)
    }

    private func offer(_ rows: [KeyBinding]) -> HyperShortcutMove.Offer {
        HyperShortcutMove.offer(.toHyper, rows: rows, base: .standard)
    }

    private func config(_ rows: [KeyBinding]) -> GuiConfig {
        var config = GuiConfig()
        config.spaces = [SpaceID(1)]
        config.layers = [KeyLayer(name: KeyLayer.defaultName, bindings: rows)]
        return config
    }

    private func combo(_ lua: String, in config: GuiConfig) -> String? {
        config.layers[0].bindings.first { $0.lua == lua }?.combo
    }

    private let floating = "KiwiDesk.toggle_floating()"
    private let display = "KiwiDesk.toggle_display_sticky()"
    private let sticky = "KiwiDesk.toggle_sticky()"

    @Test("the list is every ⌃⌥ seed row off the arrow and digit ladder")
    func listIsReadOffTheSeed() {
        let seed = Set(HyperShortcutMove.letterSeed.map(\.lua))
        // Every KiwiHub side and the app chrome are on it.
        for side in KiwiHubSide.allCases { #expect(seed.contains(side.lua)) }
        for row in DefaultKeybindings.appChromeRows() {
            #expect(seed.contains(row.lua))
        }
        // No ladder row, and nothing off the ⌃⌥ base, is.
        for row in seedLayer() where seed.contains(row.lua) {
            let parsed = KeyCombo.parse(row.combo)
            #expect(
                parsed?.modifiers.isSuperset(of: [.control, .option]) == true
            )
            #expect(parsed?.modifiers.contains(.command) == false)
        }
        #expect(!seed.contains("KiwiDesk.focus(\"left\")"))
        #expect(!seed.contains { $0.hasPrefix("KiwiDesk.focus_space(") })
    }

    @Test("a fresh seed offers every line ticked and moves it to ✦")
    func seededLinesMove() {
        let rows = seedLayer()
        let lines = offer(rows).items
        #expect(!lines.isEmpty)
        #expect(lines.allSatisfy { $0.seeded && $0.taken == nil })
        var config = config(rows)
        HyperShortcutMove.apply(
            .toHyper,
            items: Set(lines.map(\.id)),
            desktop: false,
            to: &config
        )
        #expect(combo(floating, in: config) == "hyper+f")
        #expect(
            combo("KiwiDesk.cycle_mode(\"prev\")", in: config)
                == "hyper+shift+c"
        )
        #expect(combo("KiwiDesk.open_settings()", in: config) == "hyper+comma")
        // The ladder stays.
        #expect(
            combo("KiwiDesk.focus(\"left\")", in: config)
                == "control+option+left"
        )
    }

    @Test("a rebound row on ⌃⌥ is listed unticked and moves its own chord")
    func reboundOnTheBaseIsUnticked() throws {
        var rows = seedLayer()
        let index = try #require(rows.firstIndex { $0.lua == display })
        rows[index].combo = "control+option+shift+p"
        let line = try #require(offer(rows).items.first { $0.id == display })
        #expect(!line.seeded)
        var config = config(rows)
        HyperShortcutMove.apply(
            .toHyper,
            items: [display],
            desktop: false,
            to: &config
        )
        #expect(combo(display, in: config) == "hyper+shift+p")
    }

    @Test("a row rebound off ⌃⌥ is not listed")
    func reboundOffTheBaseIsLeftOut() throws {
        var rows = seedLayer()
        let index = try #require(rows.firstIndex { $0.lua == sticky })
        rows[index].combo = "command+shift+s"
        #expect(!offer(rows).items.contains { $0.id == sticky })
        #expect(offer(rows).items.contains { $0.id == floating })
    }

    @Test("a Hyper chord the user took refuses its line, which stays")
    func takenChordRefuses() throws {
        var rows = seedLayer()
        let taker = KeyBinding(
            combo: "hyper+f",
            lua: "hs.alert('mine')",
            kind: .custom
        )
        rows.append(taker)
        let line = try #require(offer(rows).items.first { $0.id == floating })
        #expect(line.taken == taker)
        var config = config(rows)
        HyperShortcutMove.apply(
            .toHyper,
            items: [floating],
            desktop: false,
            to: &config
        )
        #expect(combo(floating, in: config) == "control+option+f")
    }

    @Test("KiwiHub's sides move with Open Settings, together or not at all")
    func kiwiHubMovesTogether() throws {
        let chrome = Set(
            KiwiHubSide.allCases.map(\.lua)
                + DefaultKeybindings.appChromeRows().map(\.lua)
        )
        let rows = seedLayer()
        let group = try #require(
            offer(rows).items.first { $0.seeds.count > 1 }
        )
        #expect(Set(group.seeds.map(\.lua)) == chrome)
        #expect(Set(group.moves.map(\.lua)) == chrome)
        // One side's ✦ chord taken: none of the four moves.
        var taken = rows
        taken.append(
            KeyBinding(combo: "hyper+k", lua: "hs.alert('k')", kind: .custom)
        )
        let refused = try #require(
            offer(taken).items.first { $0.seeds.count > 1 }
        )
        #expect(refused.taken != nil)
        var config = config(taken)
        HyperShortcutMove.apply(
            .toHyper,
            items: [refused.id],
            desktop: false,
            to: &config
        )
        for lua in chrome {
            let moved = KeyCombo.parse(combo(lua, in: config) ?? "")
            #expect(moved?.modifiers.contains(.hyper) == false)
        }
    }

    @Test("an unpicked line stays where it is")
    func unpickedStays() {
        var config = config(seedLayer())
        HyperShortcutMove.apply(
            .toHyper,
            items: [floating],
            desktop: false,
            to: &config
        )
        #expect(combo(floating, in: config) == "hyper+f")
        #expect(combo(sticky, in: config) == "control+option+s")
    }

    @Test("the reverse moves Hyper rows back and offers nothing after")
    func reverseRoundTrips() {
        let rows = seedLayer()
        var config = config(rows)
        let ids = Set(offer(rows).items.map(\.id))
        HyperShortcutMove.apply(
            .toHyper,
            items: ids,
            desktop: false,
            to: &config
        )
        #expect(offer(config.layers[0].bindings).items.isEmpty)
        let back = HyperShortcutMove.offer(
            .back,
            rows: config.layers[0].bindings,
            base: .standard
        )
        #expect(back.items.map(\.id).sorted() == ids.sorted())
        #expect(back.items.allSatisfy { $0.seeded })
        HyperShortcutMove.apply(.back, items: ids, desktop: false, to: &config)
        #expect(config.layers[0].bindings.map(\.combo) == rows.map(\.combo))
    }

    @Test("every layer moves, each judged on its own rows")
    func everyLayerMoves() {
        var config = config(seedLayer())
        config.layers.append(
            KeyLayer(
                name: "work",
                bindings: DefaultKeybindings.appChromeRows()
            )
        )
        let group = offer(seedLayer()).items.first { $0.seeds.count > 1 }
        HyperShortcutMove.apply(
            .toHyper,
            items: [group?.id ?? ""],
            desktop: false,
            to: &config
        )
        #expect(
            config.layers[1].bindings.map(\.combo)
                == ["hyper+k", "hyper+comma"]
        )
    }
}
