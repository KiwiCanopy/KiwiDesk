import AppKit
import Testing

@testable import KiwiDeskCore

/// Glyph size reaches the App Bar (#1682, #1713): at 28 pt on a
/// 40 pt strip the icon, the title's automatic size, the group badge,
/// the slot measurement and the overflow count all read the 28 pt
/// content depth, while the item keeps the full depth.
@Suite("Glyph size reaches the App Bar", .serialized)
@MainActor
struct GlyphSizeAppBarTests {
    private static let depth: CGFloat = 40
    private static let content: CGFloat = 28

    init() { LiquidGlassGate.override = { false } }

    private static func icon() -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) {
            NSColor.black.setFill()
            $0.fill()
            return true
        }
    }

    private static func look(
        edge: AppBarEdge = .top,
        content: AppBarStyle.Content = .iconAndTitle
    ) -> AppBarLook {
        var look = AppBarLook()
        look.glyphSize = Self.content
        look.liquidGlass = false
        look.edge = edge
        look.content = content
        return look
    }

    private func item(
        frame: CGRect,
        look: AppBarLook,
        count: Int = 1
    ) -> AppBarItemView {
        let view = AppBarItemView(frame: frame)
        view.configure(
            id: WindowID(1),
            text: "Zed",
            icon: Self.icon(),
            glyph: nil,
            count: count,
            active: true,
            horizontal: look.edge.isHorizontal,
            style: look
        )
        view.layout()
        return view
    }

    private var iconSide: CGFloat {
        Self.content - 2 * AppBarItemView.contentPadding
    }

    @Test("The icon and the title follow the content depth")
    func horizontalItem() {
        let look = Self.look()
        let view = item(
            frame: CGRect(x: 0, y: 0, width: 160, height: Self.depth),
            look: look
        )
        #expect(
            view.iconView.frame.size
                == CGSize(width: iconSide, height: iconSide)
        )
        #expect(abs(view.iconView.frame.midY - Self.depth / 2) <= 0.5)
        let size = look.resolvedFontSize(forContentDepth: Self.content)
        #expect(size < look.resolvedFontSize(forContentDepth: Self.depth))
        #expect(view.label.font?.pointSize == size)
    }

    @Test("The group badge follows the content depth")
    func badgeFollowsContent() {
        let view = item(
            frame: CGRect(x: 0, y: 0, width: 160, height: Self.depth),
            look: Self.look(),
            count: 3
        )
        #expect(!view.badge.isHidden)
        // The badge's text is 0.9 of its side; the disc may grow
        // past the side to fit the count.
        #expect(
            view.badge.font?.pointSize
                == AppBarItemView.badgeSide(contentSide: Self.content)
                * 0.9
        )
    }

    /// A side bar's icon slot is as long as the content is deep,
    /// and the item it measures draws the icon inside it.
    @Test("A side bar's slot and icon follow the content depth")
    func verticalSlot() {
        let look = Self.look(edge: .left)
        let items = [
            AppBarOverlay.Item(id: WindowID(1), text: "Zed", icon: nil)
        ]
        let slot = AppBarOverlay.slot(
            items: items,
            style: look,
            thickness: Self.depth,
            capAxis: 2000
        )
        #expect(slot == Self.content)
        let view = item(
            frame: CGRect(x: 0, y: 0, width: Self.depth, height: slot),
            look: look
        )
        #expect(
            view.iconView.frame.size
                == CGSize(width: iconSide, height: iconSide)
        )
        #expect(abs(view.iconView.frame.midX - Self.depth / 2) <= 0.5)
    }

    /// Icons only: the measured slot is the content's, the icon
    /// plus the slot's edge insets, never the full thickness.
    @Test("An icon-only slot measures at the content depth")
    func iconOnlySlot() {
        let look = Self.look(content: .icon)
        let items = [
            AppBarOverlay.Item(id: WindowID(1), text: "Zed", icon: nil)
        ]
        let slot = AppBarOverlay.slot(
            items: items,
            style: look,
            thickness: Self.depth,
            capAxis: 2000
        )
        #expect(slot == iconSide + 2 * AppBarItemView.edgePadding)
        #expect(slot < Self.depth)
    }

    /// The live render lays each item at the strip's full depth;
    /// only what it draws inside shrinks.
    @Test("A rendered App Bar item keeps the full depth")
    func renderedItemKeepsDepth() throws {
        let bar = AppBarManager.Bar(
            display: barTitleDisplay,
            space: SpaceID("1"),
            items: (1...3).map { appBarItem(UInt32($0), text: "W\($0)") },
            activeIndex: 0,
            strip: CGRect(x: 0, y: 0, width: 1440, height: Self.depth),
            style: Self.look(),
            capAxis: 1440
        )
        let manager = AppBarManager()
        manager.sync([bar])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        #expect(!overlay.itemViews.isEmpty)
        for view in overlay.itemViews where !view.isHidden {
            #expect(view.frame.height == Self.depth)
        }
    }

    @Test("The overflow count's automatic size follows the content")
    func countFollowsContent() throws {
        let look = Self.look()
        let bar = AppBarManager.Bar(
            display: barTitleDisplay,
            space: SpaceID("1"),
            items: (1...60).map { appBarItem(UInt32($0), text: "W\($0)") },
            activeIndex: 0,
            strip: CGRect(x: 0, y: 0, width: 1440, height: Self.depth),
            style: look,
            capAxis: 1440
        )
        let manager = AppBarManager()
        manager.sync([bar])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        #expect(!overlay.forwardCount.isHidden)
        #expect(
            overlay.forwardCount.fontSize
                == look.resolvedFontSize(forContentDepth: Self.content)
                * 0.9
        )
    }
}
