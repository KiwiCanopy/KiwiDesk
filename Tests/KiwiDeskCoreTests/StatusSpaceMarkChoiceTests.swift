import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.menu_bar_icon` (#3532): `auto` keeps the Space Bar's
/// stand-in rule, `logo` lists no screen, and `identifier` and
/// `layout` list every screen whatever its Space Bar does, the
/// layer kept under every choice. `StatusSpaceMarkTests` holds the
/// `auto` rule itself.
@Suite("Status item menu bar icon choice (#3532)", .serialized)
@MainActor
struct StatusSpaceMarkChoiceTests {
    private let built = DisplayID(7)
    private let dell = DisplayID(8)

    private func display(_ id: DisplayID, x: CGFloat) -> Display {
        Display(
            id: id,
            name: "\(id)",
            frame: CGRect(x: x, y: 0, width: 1000, height: 600)
        )
    }

    /// `main` (Stack) on the built-in, `side` (BSP) on the Dell;
    /// the Space Bar shown at rest.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-menu-bar-icon-\(UUID().uuidString)"
                )
        )
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.state.workspaces.upsertDisplay(display(built, x: 0))
        core.state.workspaces.upsertDisplay(display(dell, x: 1000))
        core.state.workspaces.assign(SpaceID("main"), to: built)
        core.state.workspaces.assign(SpaceID("side"), to: dell)
        core.state.workspaces.setMode(SpaceID("main"), .stack)
        core.state.workspaces.setMode(SpaceID("side"), .bsp)
        core.state.workspaces.activate(SpaceID("side"))
        core.state.workspaces.activate(SpaceID("main"))
        return core
    }

    private func pick(_ core: KiwiCore, _ value: String) {
        let response = core.execute(
            "kiwishelf.set_menu_bar_icon",
            args: [.string(value)]
        )
        #expect(response.isSuccess)
    }

    @Test("auto by default: the stand-in rule follows the Show")
    func defaultIsAuto() {
        #expect(KiwiShelf().menuBarIcon == .auto)
        let core = makeCore()
        #expect(core.statusSpaceMark().screens.isEmpty)
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        #expect(core.statusSpaceMark().screens.count == 2)
    }

    @Test("logo lists no screen while the Space Bar is hidden")
    func logoListsNone() {
        let core = makeCore()
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        #expect(core.statusSpaceMark().screens.count == 2)
        pick(core, "logo")
        #expect(core.tiler.settings.kiwishelf.menuBarIcon == .logo)
        #expect(core.statusSpaceMark().screens.isEmpty)
    }

    @Test("logo keeps the active layer")
    func logoKeepsTheLayer() {
        let core = makeCore()
        core.keys.defineLayer("resize", bindings: [:], icon: "star")
        core.keys.switchLayer("resize")
        pick(core, "logo")
        let mark = core.statusSpaceMark()
        #expect(mark.layer?.name == "resize")
        #expect(mark.layer?.hasIcon == true)
    }

    @Test("identifier lists every screen beside an always bar")
    func identifierListsEveryScreen() {
        let core = makeCore()
        pick(core, "identifier")
        let screens = core.statusSpaceMark().screens
        #expect(Set(screens.map(\.space)) == [SpaceID("main"), "side"])
        for screen in screens {
            #expect(
                screen.glyph
                    == StatusSpaceMark.Glyph(
                        core.spaceGlyph(for: screen.space)
                    )
            )
            #expect(screen.layout == nil)
        }
    }

    @Test("layout draws each Space's layout symbol and names it")
    func layoutDrawsTheSymbol() throws {
        let core = makeCore()
        pick(core, "layout")
        let screens = core.statusSpaceMark().screens
        let main = try #require(
            screens.first { $0.space == SpaceID("main") }
        )
        let side = try #require(
            screens.first { $0.space == SpaceID("side") }
        )
        #expect(main.glyph == .symbol(LayoutMode.stack.symbol))
        #expect(main.layout == .stack)
        #expect(side.glyph == .symbol(LayoutMode.bsp.symbol))
        #expect(side.layout == .bsp)
    }

    @Test("a tiling-off Space keeps its layout symbol and the pause")
    func tilingOffKeepsTheSymbol() {
        let core = makeCore()
        pick(core, "layout")
        #expect(core.execute("toggle_tiling").isSuccess)
        #expect(core.isTilingOff(SpaceID("main")))
        let main = core.statusSpaceMark().screens.first {
            $0.space == SpaceID("main")
        }
        #expect(main?.glyph == .symbol(LayoutMode.stack.symbol))
        #expect(main?.tilingOff == true)
    }

    @Test("an unknown value is refused and changes nothing")
    func unknownValueRefuses() {
        let core = makeCore()
        let response = core.execute(
            "kiwishelf.set_menu_bar_icon",
            args: [.string("space")]
        )
        #expect(!response.isSuccess)
        #expect(core.tiler.settings.kiwishelf.menuBarIcon == .auto)
    }

    @Test("the key round-trips and decodes sparsely")
    func codingRoundTrips() throws {
        var shelf = KiwiShelf()
        shelf.menuBarIcon = .layout
        let data = try JSONEncoder().encode(shelf)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        #expect(json["menu_bar_icon"] as? String == "layout")
        let back = try JSONDecoder().decode(KiwiShelf.self, from: data)
        #expect(back.menuBarIcon == .layout)
        let empty = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data("{}".utf8)
        )
        #expect(empty.menuBarIcon == .auto)
    }
}
