import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar's layer item (#1169): the active shortcut layer
/// leads the Space run while it is not `default`, and is never a
/// click, drag or drop target. The driver half builds the item;
/// the overlay half keeps it out of every Space-keyed channel.
/// The refresh wiring — the bar following the `layer_change`
/// bus event — is `SpaceBarLayerRefreshTests`, on a real screen.
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

    // MARK: driver

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

    // MARK: overlay

    /// A layer item ahead of two Spaces, rendered through the
    /// manager so the arm under test is the production one.
    private static func shown() throws -> SpaceBarOverlay {
        LiquidGlassGate.override = { false }
        var style = SpaceBarStyle()
        style.backgroundStyle = .boxed
        style.liquidGlass = false
        let items = [
            SpaceBarOverlay.Item(
                layer: "resize",
                glyph: .text("RE", tinted: true)
            ),
            SpaceBarOverlay.Item(
                space: SpaceID("1"),
                spaceGlyph: .text("1", tinted: true),
                apps: [],
                active: true,
                overflow: 0,
                focusInOverflow: false
            ),
            SpaceBarOverlay.Item(
                space: SpaceID("2"),
                spaceGlyph: .text("2", tinted: true),
                apps: [],
                active: false,
                overflow: 0,
                focusInOverflow: false
            ),
        ]
        let manager = SpaceBarManager()
        manager.sync([
            SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: items,
                strip: barTitleStrip,
                style: style,
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ])
        return try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
    }

    @Test("the layer item is no drop target")
    func noDropTarget() throws {
        let overlay = try Self.shown()
        #expect(overlay.itemViews.count == 3)
        #expect(
            overlay.hitFrames.map(\.space) == [
                SpaceID("1"), SpaceID("2"),
            ]
        )
        // The first item's frame is drawn, and a point inside it
        // resolves to no Space.
        let first = overlay.itemViews[0].frame
        #expect(first.width > 0)
        let container = overlay.itemContainer.frame
        let probe = CGPoint(
            x: barTitleStrip.minX + container.minX + first.midX,
            y: barTitleStrip.minY + container.minY + first.midY
        )
        #expect(overlay.spaceItem(atGlobal: probe) == nil)
    }

    @Test("clearing the drag hover leaves the layer item alone")
    func dragHoverNeverMatchesTheLayerItem() throws {
        let overlay = try Self.shown()
        let layer = overlay.itemViews[0]
        #expect(layer.space == nil)
        overlay.setDragHover(SpaceID("2"))
        #expect(!layer.isDragHovered)
        #expect(overlay.itemViews[2].isDragHovered)
        // nil clears — and a nil Space must not READ as the
        // layer item's own nil.
        overlay.setDragHover(nil)
        #expect(!layer.isDragHovered)
        #expect(!overlay.itemViews[2].isDragHovered)
    }

    @Test("a click on the layer item selects nothing")
    func clickSelectsNothing() throws {
        let overlay = try Self.shown()
        var selected: [SpaceID] = []
        overlay.onSelect = { selected.append($0) }
        let down = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        overlay.itemViews[0].mouseDown(with: down)
        #expect(selected.isEmpty)
        // The control: a Space item still selects.
        overlay.itemViews[2].mouseDown(with: down)
        #expect(selected == [SpaceID("2")])
    }

    @Test("the layer item announces its layer, not a Space")
    func announcesTheLayer() throws {
        LocalizationManager.shared.select("en")
        let overlay = try Self.shown()
        let layer = overlay.itemViews[0]
        #expect(layer.isAccessibilityElement())
        #expect(layer.accessibilityRole() == .image)
        #expect(layer.accessibilityLabel() == "Shortcut layer resize")
        #expect(overlay.itemViews[1].accessibilityRole() == .button)
    }
}
