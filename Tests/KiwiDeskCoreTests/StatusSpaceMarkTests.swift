import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The menu bar item's layer and Space mark (#1413), the Core
/// half: the active layer's glyph (none on `default`) on every
/// publish, and the Space each screen SHOWS — its icon or its
/// full name — only while the bar is off, published off the
/// bar's own refresh on change only. The drawing and the name
/// are `StatusItemSpaceMarkTests`' (GUI).
@Suite("Status item Space mark (#1413)", .serialized)
@MainActor
struct StatusSpaceMarkTests {
    private let built = DisplayID(7)
    private let dell = DisplayID(8)

    private func display(_ id: DisplayID, x: CGFloat) -> Display {
        Display(
            id: id,
            name: "\(id)",
            frame: CGRect(x: x, y: 0, width: 1000, height: 600)
        )
    }

    /// Spaces `main` and `2` on the built-in, `side` on the Dell;
    /// `main` active. The bar is OFF.
    private func makeCore(screens: Int = 1) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-status-mark-\(UUID().uuidString)"
                )
        )
        core.tiler.settings.spaceBarStyle.enabled = false
        core.state.workspaces.upsertDisplay(display(built, x: 0))
        core.state.workspaces.assign(SpaceID("main"), to: built)
        core.state.workspaces.assign(SpaceID("2"), to: built)
        if screens > 1 {
            core.state.workspaces.upsertDisplay(display(dell, x: 1000))
            core.state.workspaces.assign(SpaceID("side"), to: dell)
            core.state.workspaces.activate(SpaceID("side"))
        }
        core.state.workspaces.activate(SpaceID("main"))
        return core
    }

    /// The bar on keeps the item as it was: no screens, and the
    /// layer still carried so the layer icon has one channel.
    @Test("the bar on lists no screen but still carries the layer")
    func barOnListsNoScreen() {
        let core = makeCore()
        core.keys.defineLayer("resize", bindings: [:], icon: "star")
        core.keys.switchLayer("resize")
        core.tiler.settings.spaceBarStyle.enabled = true
        let on = core.statusSpaceMark()
        #expect(on.screens.isEmpty)
        #expect(on.layer?.name == "resize")
        core.tiler.settings.spaceBarStyle.enabled = false
        #expect(!core.statusSpaceMark().screens.isEmpty)
    }

    @Test("an icon-less Space shows its full name, not the monogram")
    func fullNameWithoutIcon() {
        let mark = makeCore().statusSpaceMark()
        #expect(mark.layer == nil)
        #expect(mark.screens.count == 1)
        #expect(mark.screens.first?.space == SpaceID("main"))
        #expect(mark.screens.first?.glyph == .text("main", tinted: true))
        #expect(mark.screens.first?.display.id == built)
    }

    @Test("a configured icon draws as the symbol or the emoji")
    func configuredIcon() throws {
        let core = makeCore()
        core.tiler.settings.spaceIcons[SpaceID("main")] = "envelope"
        #expect(
            core.statusSpaceMark().screens.first?.glyph
                == .symbol("envelope")
        )
        core.tiler.settings.spaceIcons[SpaceID("main")] = "🌐"
        let glyph = try #require(core.statusSpaceMark().screens.first?.glyph)
        #expect(glyph == .text("🌐", tinted: false))
        #expect(glyph.keepsColour)
        #expect(!StatusSpaceMark.Glyph.text("main", tinted: true).keepsColour)
        #expect(!StatusSpaceMark.Glyph.symbol("envelope").keepsColour)
    }

    @Test("the mark follows the Space the screen shows")
    func followsTheShownSpace() {
        let core = makeCore()
        core.state.workspaces.activate(SpaceID("2"))
        #expect(
            core.statusSpaceMark().screens.first?.space == SpaceID("2")
        )
    }

    /// The layer's glyph is the bar's, and `hasIcon` tells the
    /// monogram from an icon so the bar-on item can keep the
    /// brand glyph for an icon-less layer.
    @Test("a non-default layer leads with its icon or its monogram")
    func layerLeads() throws {
        let core = makeCore()
        core.keys.defineLayer(
            "resize",
            bindings: [:],
            icon: "arrow.left.and.right"
        )
        core.keys.switchLayer("resize")
        let layer = try #require(core.statusSpaceMark().layer)
        #expect(layer.name == "resize")
        #expect(layer.glyph == .symbol("arrow.left.and.right"))
        #expect(layer.hasIcon)
        core.keys.defineLayer("service", bindings: [:])
        core.keys.switchLayer("service")
        let monogram = try #require(core.statusSpaceMark().layer)
        #expect(monogram.glyph == .text("SE", tinted: true))
        #expect(!monogram.hasIcon)
        core.keys.switchLayer("default")
        #expect(core.statusSpaceMark().layer == nil)
    }

    @Test("every screen's shown Space is listed")
    func everyScreenIsListed() {
        let mark = makeCore(screens: 2).statusSpaceMark()
        let byDisplay = Dictionary(
            uniqueKeysWithValues: mark.screens.map {
                ($0.display.id, $0.space)
            }
        )
        #expect(
            byDisplay == [built: SpaceID("main"), dell: SpaceID("side")]
        )
    }

    /// The seam: the bar's refresh publishes, on change only,
    /// and the bar coming on publishes the screenless shape.
    @Test("the bar's refresh publishes the mark on change only")
    func publishedOffTheBarRefresh() {
        let core = makeCore()
        var published: [StatusSpaceMark] = []
        core.onStatusSpaceMarkChange = { published.append($0) }
        core.updateSpaceBar()
        #expect(published.count == 1)
        #expect(published.last?.screens.first?.space == SpaceID("main"))
        #expect(core.spaceBars.statusMark == published.last)
        core.updateSpaceBar()
        #expect(published.count == 1)
        core.state.workspaces.activate(SpaceID("2"))
        core.updateSpaceBar()
        #expect(published.count == 2)
        #expect(published.last?.screens.first?.space == SpaceID("2"))
        core.tiler.settings.spaceBarStyle.enabled = true
        core.updateSpaceBar()
        #expect(published.count == 3)
        #expect(published.last?.screens.isEmpty == true)
    }

    /// A layer switch retiles nothing, so the mark rides the
    /// bar's `layer_change` sink, wired at bootstrap (#1169).
    @Test("a layer switch publishes without a retile")
    func layerSwitchPublishes() {
        let core = makeCore()
        var published: [StatusSpaceMark] = []
        core.onStatusSpaceMarkChange = { published.append($0) }
        core.keys.defineLayer("resize", bindings: [:])
        core.keys.switchLayer("resize")
        #expect(published.last?.layer?.name == "resize")
    }
}
