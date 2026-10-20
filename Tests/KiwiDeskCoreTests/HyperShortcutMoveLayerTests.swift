import Foundation
import Testing

@testable import KiwiDeskCore

/// The Hyper move across layers (#1870): it applies exactly the moves
/// the sheet showed, read off the default layer — a row another
/// layer rebound stays, and a line refused in one layer stays there
/// whole — and a Desktop row a top-up adds to a staged draft takes
/// the draft's base.
@Suite("Hyper move offer: what reaches each layer")
struct HyperShortcutMoveLayerTests {
    private let floating = "KiwiDesk.toggle_floating()"

    private func config(work: [KeyBinding]) -> GuiConfig {
        var config = GuiConfig()
        config.spaces = [SpaceID(1)]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: DefaultKeybindings.bindings(
                    spaces: config.spaces,
                    resizeStep: 50
                )
            ),
            KeyLayer(name: "work", bindings: work),
        ]
        return config
    }

    private func moveAll(_ config: inout GuiConfig) {
        let offer = HyperShortcutMove.offer(
            .toHyper,
            rows: config.layers[0].bindings,
            base: config.shortcutBase
        )
        HyperShortcutMove.apply(
            offer,
            items: Set(offer.items.map(\.id)),
            desktop: false,
            to: &config
        )
    }

    @Test("a row another layer rebound on ⌃⌥ is not moved unseen")
    func otherLayerReboundStays() {
        var config = config(work: [
            KeyBinding(
                combo: "control+option+shift+f",
                lua: floating,
                kind: .navigation
            )
        ])
        moveAll(&config)
        #expect(
            config.layers[0].bindings.first { $0.lua == floating }?.combo
                == "hyper+f"
        )
        #expect(
            config.layers[1].bindings.map(\.combo)
                == ["control+option+shift+f"]
        )
    }

    @Test("a row spelled differently on the chord shown still moves")
    func otherSpellingMoves() {
        var config = config(work: [
            KeyBinding(
                combo: "alt+ctrl+f",
                lua: floating,
                kind: .navigation
            )
        ])
        moveAll(&config)
        #expect(config.layers[1].bindings.map(\.combo) == ["hyper+f"])
    }

    @Test("a line refused in one layer stays whole there")
    func refusedInOneLayerStaysWhole() {
        var config = config(
            work: DefaultKeybindings.appChromeRows() + [
                KeyBinding(combo: "hyper+k", lua: "hs.x()", kind: .custom)
            ]
        )
        moveAll(&config)
        let work = config.layers[1].bindings.prefix(2).map(\.combo)
        #expect(work == ["control+option+k", "control+option+comma"])
        let base = config.layers[0].bindings.first {
            $0.lua == DefaultKeybindings.openSettingsRow().lua
        }
        #expect(base?.combo == "hyper+comma")
    }

    @Test("a top-up row rebases onto a staged base, and back")
    func rebasedTopUpRow() throws {
        let seeded = try #require(DefaultKeybindings.desktopRow(4))
        let onHyper = ShortcutBase.hyper.rebased(seeded)
        #expect(onHyper.combo == "hyper+option+4")
        #expect(ShortcutBase.standard.rebased(onHyper) == seeded)
        let size = try #require(
            DefaultKeybindings.resizeRows(step: 1).first
        )
        #expect(ShortcutBase.hyper.rebased(size) == size)
    }
}
