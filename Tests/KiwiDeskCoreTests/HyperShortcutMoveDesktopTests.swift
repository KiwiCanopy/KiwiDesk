import Foundation
import Testing

@testable import KiwiDeskCore

/// The Hyper move offer's Desktop line (#1870): it moves the seeded
/// Go to Desktop rows AND the stored base, which the top-up then
/// writes new Desktops on; only the reverse resets it.
@Suite("Hyper move offer: the Desktop line and base", .serialized)
@MainActor
struct HyperShortcutMoveDesktopTests {
    /// Applies the offer the default layer shows, as the sheet does.
    private func move(
        _ direction: HyperShortcutMove.Direction,
        items: Set<String>,
        desktop: Bool,
        to config: inout GuiConfig
    ) {
        let rows = config.layers.first { $0.isDefault }?.bindings ?? []
        let offer = HyperShortcutMove.offer(
            direction,
            rows: rows,
            base: config.shortcutBase
        )
        HyperShortcutMove.apply(
            offer,
            items: items,
            desktop: desktop,
            to: &config
        )
    }

    private func lua(_ number: Int) -> String {
        "KiwiDesk.focus_desktop(\(number))"
    }

    /// The seed's letters with `desktops`' rows: the Desktop line
    /// rides the letter offer, so a fixture without letters has none.
    private func config(desktops: [Int]) -> GuiConfig {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: HyperShortcutMove.letterSeed
                    + desktops.compactMap {
                        DefaultKeybindings.desktopRow($0, base: .standard)
                    }
            )
        ]
        return config
    }

    private func combo(_ number: Int, in config: GuiConfig) -> String? {
        config.layers[0].bindings.first { $0.lua == lua(number) }?.combo
    }

    @Test("the line moves the seeded rows and sets the base")
    func lineMovesRowsAndBase() throws {
        var config = config(desktops: [1, 2])
        let two = try #require(
            config.layers[0].bindings.firstIndex { $0.lua == lua(2) }
        )
        config.layers[0].bindings[two].combo = "control+option+2"
        move(
            .toHyper,
            items: [],
            desktop: true,
            to: &config
        )
        #expect(combo(1, in: config) == "hyper+option+1")
        // A rebound Desktop row keeps its own chord.
        #expect(combo(2, in: config) == "control+option+2")
        #expect(config.shortcutBase == .hyper)
    }

    @Test("without the line, neither the rows nor the base move")
    func noLineMovesNothing() {
        var config = config(desktops: [1])
        move(
            .toHyper,
            items: [],
            desktop: false,
            to: &config
        )
        #expect(combo(1, in: config) == "control+option+shift+command+1")
        #expect(config.shortcutBase == .standard)
    }

    @Test("a taken ✦ digit keeps that row and names its holder")
    func takenDigitStays() throws {
        var config = config(desktops: [1, 2])
        let taker = KeyBinding(
            combo: "hyper+option+2",
            lua: "hs.x()",
            kind: .custom
        )
        config.layers[0].bindings.append(taker)
        let line = try #require(
            HyperShortcutMove.offer(
                .toHyper,
                rows: config.layers[0].bindings,
                base: .standard
            ).desktop
        )
        #expect(line.kept.map(\.holder) == [taker])
        move(
            .toHyper,
            items: [],
            desktop: true,
            to: &config
        )
        #expect(combo(2, in: config) == "control+option+shift+command+2")
        #expect(config.shortcutBase == .hyper)
    }

    @Test("a declined Desktop line retires with the letters")
    func declinedLineRetires() {
        var config = config(desktops: [1, 2])
        let letters = HyperShortcutMove.offer(
            .toHyper,
            rows: config.layers[0].bindings,
            base: .standard
        ).items.map(\.id)
        move(.toHyper, items: Set(letters), desktop: false, to: &config)
        let after = HyperShortcutMove.offer(
            .toHyper,
            rows: config.layers[0].bindings,
            base: config.shortcutBase
        )
        #expect(after.isEmpty)
        #expect(combo(1, in: config) == "control+option+shift+command+1")
    }

    @Test("a declined line retires; the reverse stays while the base is ✦")
    func lineRetiresAndReverseStays() {
        // Forward, with no seeded Desktop row: nothing to offer, so a
        // declined line retires with the letters.
        #expect(
            HyperShortcutMove.offer(.toHyper, rows: [], base: .standard)
                .desktop == nil
        )
        #expect(
            HyperShortcutMove.offer(.toHyper, rows: [], base: .hyper)
                .desktop == nil
        )
        // Letters left but no seeded Desktop row: no line either.
        #expect(
            HyperShortcutMove.offer(
                .toHyper,
                rows: HyperShortcutMove.letterSeed,
                base: .standard
            ).desktop == nil
        )
        // The reverse alone resets the base, rows or none.
        let back = HyperShortcutMove.offer(.back, rows: [], base: .hyper)
        #expect(back.desktop?.base == .standard)
        #expect(!back.isEmpty)
    }

    @Test("the reverse moves the rows back and resets the base")
    func reverseResetsTheBase() {
        var config = config(desktops: [1, 3])
        move(
            .toHyper,
            items: [],
            desktop: true,
            to: &config
        )
        move(.back, items: [], desktop: true, to: &config)
        #expect(combo(1, in: config) == "control+option+shift+command+1")
        #expect(combo(3, in: config) == "control+option+shift+command+3")
        #expect(config.shortcutBase == .standard)
    }

    @Test("the top-up writes a new Desktop's row on the base")
    func topUpFollowsTheBase() {
        let rows = DefaultKeybindings.desktopTopUp(
            existing: [],
            desktops: [1, 2],
            above: 0,
            base: .hyper
        )
        #expect(rows.map(\.combo) == ["hyper+option+1", "hyper+option+2"])
        // A ✦ digit the user took leaves that Desktop unbound.
        let taken = DefaultKeybindings.desktopTopUp(
            existing: [
                KeyBinding(
                    combo: "hyper+option+1",
                    lua: "hs.x()",
                    kind: .custom
                )
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
        stored.shortcutBase = .hyper
        try core.guiConfigStore.save(stored)
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        core.topUpDesktopShortcuts(desktops: [1])
        let rows = core.persistedGuiConfig()?.layers.first(where: \.isDefault)?
            .bindings.filter { $0.lua == lua(1) }
        #expect(rows?.map(\.combo) == ["hyper+option+1"])
    }

    @Test("gui.json carries the base; absence is the seeded tier")
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
}
