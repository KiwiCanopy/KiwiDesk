import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar's layer item (#1169), the driver half: the
/// active shortcut layer builds one item while it is not
/// `default`, with its icon or the shared monogram. The overlay
/// half — every Space-keyed channel the item stays out of, and
/// its section rule — is `SpaceBarLayerOverlayTests`; the
/// refresh wiring is `SpaceBarLayerRefreshTests`.
@Suite("Space Bar layer item (#1169)", .serialized)
@MainActor
struct SpaceBarLayerItemTests {
    private static func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-layer-item-\(UUID().uuidString)"
                )
        )
    }

    @Test("the default layer builds no item")
    func defaultLayerBuildsNothing() {
        let core = Self.makeCore()
        #expect(core.keys.currentLayer == "default")
        #expect(core.spaceBarLayerItem() == nil)
    }

    @Test("an SF Symbol icon draws as the symbol")
    func symbolIcon() throws {
        let core = Self.makeCore()
        core.keys.defineLayer(
            "resize",
            bindings: [:],
            icon: "arrow.left.and.right"
        )
        core.keys.switchLayer("resize")
        let item = try #require(core.spaceBarLayerItem())
        #expect(item.identity == .layer("resize"))
        #expect(item.spaceGlyph == .symbol("arrow.left.and.right"))
        #expect(item.space == nil)
        #expect(item.apps.isEmpty)
        #expect(!item.active)
    }

    @Test("an emoji icon draws untinted, like a Space's")
    func emojiIcon() throws {
        let core = Self.makeCore()
        core.keys.defineLayer("service", bindings: [:], icon: "⚙️")
        core.keys.switchLayer("service")
        let item = try #require(core.spaceBarLayerItem())
        #expect(item.spaceGlyph == .text("⚙️", tinted: false))
    }

    @Test("an icon-less layer takes the Space monogram's cut")
    func monogram() throws {
        let core = Self.makeCore()
        core.keys.defineLayer("resize", bindings: [:])
        core.keys.switchLayer("resize")
        let item = try #require(core.spaceBarLayerItem())
        #expect(item.spaceGlyph == .text("RE", tinted: true))
    }

    @Test("switching back to default drops the item")
    func backToDefault() {
        let core = Self.makeCore()
        core.keys.defineLayer("resize", bindings: [:])
        core.keys.switchLayer("resize")
        #expect(core.spaceBarLayerItem() != nil)
        core.keys.switchLayer("default")
        #expect(core.spaceBarLayerItem() == nil)
    }
}
