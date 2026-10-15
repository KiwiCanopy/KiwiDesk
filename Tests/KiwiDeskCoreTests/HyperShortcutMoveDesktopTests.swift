import Foundation
import Testing

@testable import KiwiDeskCore

/// The Hyper move offer's Desktop line (#1870): it moves the seeded
/// Go to Desktop rows AND the stored base, which the top-up then
/// writes new Desktops on; only the reverse resets it.
@Suite("Hyper move offer: the Desktop line and base", .serialized)
@MainActor
struct HyperShortcutMoveDesktopTests {
    private final class Mark { var value = 0 }

    private func lua(_ number: Int) -> String {
        "KiwiDesk.focus_desktop(\(number))"
    }

    private func config(desktops: [Int]) -> GuiConfig {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: desktops.compactMap {
                    DefaultKeybindings.desktopRow($0)
                }
            )
        ]
        return config
    }

    private func combo(_ number: Int, in config: GuiConfig) -> String? {
        config.layers[0].bindings.first { $0.lua == lua(number) }?.combo
    }

    @Test("the line moves the seeded rows and sets the base")
    func lineMovesRowsAndBase() {
        var config = config(desktops: [1, 2])
        config.layers[0].bindings[1].combo = "control+option+2"
        HyperShortcutMove.apply(
            .toHyper,
            items: [],
            desktop: true,
            to: &config
        )
        #expect(combo(1, in: config) == "hyper+1")
        // A rebound Desktop row keeps its own chord.
        #expect(combo(2, in: config) == "control+option+2")
        #expect(config.desktopShortcutBase == .hyper)
    }

    @Test("without the line, neither the rows nor the base move")
    func noLineMovesNothing() {
        var config = config(desktops: [1])
        HyperShortcutMove.apply(
            .toHyper,
            items: [],
            desktop: false,
            to: &config
        )
        #expect(combo(1, in: config) == "control+option+shift+command+1")
        #expect(config.desktopShortcutBase == .standard)
    }

    @Test("a taken ✦ digit keeps that row and names its holder")
    func takenDigitStays() throws {
        var config = config(desktops: [1, 2])
        let taker = KeyBinding(combo: "hyper+2", lua: "hs.x()", kind: .custom)
        config.layers[0].bindings.append(taker)
        let line = try #require(
            HyperShortcutMove.offer(
                .toHyper,
                rows: config.layers[0].bindings,
                base: .standard
            ).desktop
        )
        #expect(line.kept.map(\.holder) == [taker])
        HyperShortcutMove.apply(
            .toHyper,
            items: [],
            desktop: true,
            to: &config
        )
        #expect(combo(2, in: config) == "control+option+shift+command+2")
        #expect(config.desktopShortcutBase == .hyper)
    }

    @Test("the line is offered with no Desktop rows, for Desktops to come")
    func lineWithoutRows() {
        let offer = HyperShortcutMove.offer(
            .toHyper,
            rows: [],
            base: .standard
        )
        #expect(offer.desktop?.base == .hyper)
        #expect(
            HyperShortcutMove.offer(.toHyper, rows: [], base: .hyper)
                .desktop == nil
        )
    }

    @Test("the reverse moves the rows back and resets the base")
    func reverseResetsTheBase() {
        var config = config(desktops: [1, 3])
        HyperShortcutMove.apply(
            .toHyper,
            items: [],
            desktop: true,
            to: &config
        )
        HyperShortcutMove.apply(.back, items: [], desktop: true, to: &config)
        #expect(combo(1, in: config) == "control+option+shift+command+1")
        #expect(combo(3, in: config) == "control+option+shift+command+3")
        #expect(config.desktopShortcutBase == .standard)
    }

    @Test("the top-up writes a new Desktop's row on the base")
    func topUpFollowsTheBase() {
        let rows = DefaultKeybindings.desktopTopUp(
            existing: [],
            desktops: [1, 2],
            above: 0,
            base: .hyper
        )
        #expect(rows.map(\.combo) == ["hyper+1", "hyper+2"])
        // A ✦ digit the user took leaves that Desktop unbound.
        let taken = DefaultKeybindings.desktopTopUp(
            existing: [
                KeyBinding(combo: "hyper+1", lua: "hs.x()", kind: .custom)
            ],
            desktops: [1, 2],
            above: 0,
            base: .hyper
        )
        #expect(taken.map(\.lua) == [lua(2)])
    }

    @Test("topUpDesktopShortcuts reads the stored base")
    func topUpReadsTheStore() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-hyper-base-\(UUID().uuidString)")
        )
        var stored = GuiConfig()
        stored.desktopShortcutBase = .hyper
        try core.guiConfigStore.save(stored)
        let mark = Mark()
        core.desktopMemory.readShortcutMark = { mark.value }
        core.desktopMemory.writeShortcutMark = { mark.value = $0 }
        core.topUpDesktopShortcuts(desktops: [1])
        let rows = core.persistedGuiConfig()?.layers.first(where: \.isDefault)?
            .bindings.filter { $0.lua == lua(1) }
        #expect(rows?.map(\.combo) == ["hyper+1"])
    }

    @Test("gui.json carries the base; absence is the seeded tier")
    func storedShape() throws {
        var config = GuiConfig()
        config.desktopShortcutBase = .hyper
        let data = try JSONEncoder().encode(config)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"desktop_shortcut_base\":\"hyper\""))
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.desktopShortcutBase == .hyper)
        let bare = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data("{}".utf8)
        )
        #expect(bare.desktopShortcutBase == .standard)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                GuiConfig.self,
                from: Data(#"{"desktop_shortcut_base":"meta"}"#.utf8)
            )
        }
    }
}
