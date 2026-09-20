import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar's layer item (#1169), the overlay half: rendered
/// through `SpaceBarManager.sync` so the arm under test is the
/// production one, the item is no click, drag or drop target,
/// draws at full strength, announces its layer, and carries the
/// front segment's section rule between it and the first Space.
@Suite("Space Bar layer item overlay (#1169)", .serialized)
@MainActor
struct SpaceBarLayerOverlayTests {

    /// A layer item ahead of two Spaces.
    private static func shown(
        withLayer: Bool = true,
        glyph: SpaceGlyph = .text("RE", tinted: true),
        edge: AppBarEdge = .top
    ) throws -> SpaceBarOverlay {
        LiquidGlassGate.override = { false }
        var style = SpaceBarStyle()
        style.backgroundStyle = .boxed
        style.liquidGlass = false
        style.edge = edge
        var items = [
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
        if withLayer {
            items.insert(
                SpaceBarOverlay.Item(layer: "resize", glyph: glyph),
                at: 0
            )
        }
        let strip =
            edge.isHorizontal
            ? barTitleStrip
            : CGRect(x: 0, y: 0, width: 28, height: 1440)
        let manager = SpaceBarManager()
        manager.sync([
            SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: items,
                strip: strip,
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
        // A point inside the layer item's drawn frame resolves to
        // no Space, while the same probe over the first Space item
        // resolves to it — the control that makes the nil mean
        // something. `spaceItem(atGlobal:)` takes a Cocoa point.
        func probe(_ view: NSView) -> CGPoint {
            let container = overlay.itemContainer.frame
            let ax = CGPoint(
                x: barTitleStrip.minX + container.minX
                    + view.frame.midX,
                y: barTitleStrip.minY + container.minY
                    + view.frame.midY
            )
            return CGPoint(
                x: ax.x,
                y: GeometryUtils.primaryHeight - ax.y
            )
        }
        #expect(overlay.itemViews[0].frame.width > 0)
        #expect(
            overlay.spaceItem(atGlobal: probe(overlay.itemViews[1]))
                == SpaceID("1")
        )
        #expect(
            overlay.spaceItem(atGlobal: probe(overlay.itemViews[0]))
                == nil
        )
    }

    /// An emoji icon takes no tint, so the alpha channel is the
    /// one that could dim the layer item to "not current".
    @Test("an emoji layer icon draws at full strength")
    func emojiLayerIsNotDimmed() throws {
        let overlay = try Self.shown(glyph: .text("⚙️", tinted: false))
        let layer = overlay.itemViews[0]
        #expect(layer.identifierLabel.alphaValue == 1)
        // The control: a not-current Space's untinted glyph dims.
        let other = try Self.shown(withLayer: false)
        other.itemViews[1].configure(
            identity: .space(SpaceID("2")),
            spaceGlyph: .text("⚙️", tinted: false),
            apps: [],
            active: false,
            horizontal: true,
            style: SpaceBarStyle(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        #expect(
            other.itemViews[1].identifierLabel.alphaValue
                == SpaceBarStyle().dimFactor
        )
    }

    /// A pointer resting on the Space the slot drew must not
    /// leave its hover fill under the layer glyph (review).
    @Test("a resting hover does not survive into the layer item")
    func hoverResetOnIdentityChange() throws {
        let overlay = try Self.shown(withLayer: false)
        let view = overlay.itemViews[1]
        let entered = try #require(
            NSEvent.enterExitEvent(
                with: .mouseEntered,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                trackingNumber: 0,
                userData: nil
            )
        )
        view.mouseEntered(with: entered)
        try #require(view.isHovered)
        view.configure(
            identity: .layer("resize"),
            spaceGlyph: .text("RE", tinted: true),
            apps: [],
            active: false,
            horizontal: true,
            style: SpaceBarStyle(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        #expect(!view.isHovered)
        // And a layer item never takes the hover at all.
        view.mouseEntered(with: entered)
        #expect(!view.isHovered)
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

    /// The rule between the layer item and the first Space is
    /// the front segment's: 2 pt, full depth, a gap on each side,
    /// carried inside the layer item's slot so the run measures
    /// it.
    @Test("a section rule stands between the layer and the Spaces")
    func sectionRule() throws {
        let overlay = try Self.shown()
        let rule = overlay.layerDivider
        #expect(!rule.isHidden)
        let layer = overlay.itemViews[0].frame
        let first = overlay.itemViews[1].frame
        let gap = SpaceBarStyle().itemGap
        #expect(rule.frame.width == BarDivider.sectionThickness)
        #expect(rule.frame.height == barTitleStrip.height)
        #expect(rule.frame.minX == layer.maxX + gap)
        #expect(first.minX == rule.frame.maxX + gap)
        // The item keeps its own length: the rule rides the slot,
        // never the glyph cell.
        #expect(
            layer.width
                == SpaceBarItemView.autoLength(
                    appCount: 0,
                    depth: barTitleStrip.height
                )
        )
        #expect(overlay.layerDivider.superview === overlay.itemContainer)
    }

    /// The same rule on a vertical bar: the trim and the placement
    /// take the other axis.
    @Test("the section rule stands on a vertical bar too")
    func sectionRuleVertical() throws {
        let overlay = try Self.shown(edge: .left)
        let rule = overlay.layerDivider
        #expect(!rule.isHidden)
        let layer = overlay.itemViews[0].frame
        let first = overlay.itemViews[1].frame
        let gap = SpaceBarStyle().itemGap
        #expect(rule.frame.height == BarDivider.sectionThickness)
        #expect(rule.frame.width == 28)
        #expect(rule.frame.minY == layer.maxY + gap)
        #expect(first.minY == rule.frame.maxY + gap)
        #expect(
            layer.height
                == SpaceBarItemView.autoLength(appCount: 0, depth: 28)
        )
        #expect(layer.width == 28)
    }

    @Test("no layer item, no rule")
    func ruleHiddenWithoutALayer() throws {
        let overlay = try Self.shown(withLayer: false)
        #expect(overlay.layerDivider.isHidden)
        #expect(overlay.itemViews.count == 2)
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
