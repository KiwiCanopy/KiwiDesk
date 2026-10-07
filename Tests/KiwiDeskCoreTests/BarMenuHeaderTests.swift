import AppKit
import Testing

@testable import KiwiDeskCore

/// #2024: a right-click on an app names the app at the top — a
/// section header in the menu, never a VoiceOver action, since it
/// acts on nothing — and the front-app segment offers its window's
/// rows rather than the shelf section alone.
@Suite("Bar menu app header (#2024)")
@MainActor
struct BarMenuHeaderTests {
    private func rows() -> [BarMenuRow] {
        [.header("Safari"), .action("New Window") {}, .separator]
    }

    @Test("a header is a section header in the menu")
    func headerIsASectionHeader() {
        let menu = BarMenu.make(rows())
        #expect(menu.items[0].isSectionHeader)
        #expect(menu.items[0].title == "Safari")
        #expect(!menu.items[1].isSectionHeader)
    }

    @Test("VoiceOver hears the rows, never the header")
    func headerIsNoAction() {
        #expect(
            BarMenu.accessibilityActions(rows()).map(\.name)
                == ["New Window"]
        )
    }

    @Test("a surface asks its point hit before its own")
    func surfaceAsksThePointFirst() {
        let menus = BarContextMenus()
        menus.rows = { hit in [.action("\(hit)") {}] }
        let surface = BarMenuView(
            frame: NSRect(x: 0, y: 0, width: 100, height: 30)
        )
        surface.contextMenus = menus
        let click = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: NSPoint(x: 10, y: 10),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
        #expect(surface.menu(for: click)?.items.first?.title == "empty")
        surface.hitAt = { _ in .count }
        #expect(surface.menu(for: click)?.items.first?.title == "count")
    }

    /// The segment answers by point: the section root asks here
    /// before its own shelf hit, and a point off the segment, or no
    /// front app, falls through.
    @Test("the front-app segment's point hit is its window's rows")
    func frontSegmentHitsItsWindow() throws {
        let display = DisplayID(7)
        var style = SpaceBarLook()
        style.showFrontApp = true
        let manager = SpaceBarManager()
        let menus = BarContextMenus()
        menus.rows = { hit in [.action("\(hit)") {}] }
        manager.contextMenus = menus
        let front = SpaceBarItemView.App(
            name: "App9",
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            focused: false,
            count: 1,
            windows: [WindowID(9)]
        )
        manager.sync([
            SpaceBarManager.Bar(
                display: display,
                items: [
                    SpaceBarOverlay.Item(
                        space: SpaceID("1"),
                        spaceGlyph: .text("1", tinted: true),
                        apps: [],
                        active: true,
                        after: .none
                    )
                ],
                frontApp: front,
                frontWindow: WindowID(9),
                strip: CGRect(x: 0, y: 0, width: 800, height: 32),
                style: style,
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ])
        let overlay = try #require(manager.overlayForTesting(display))
        let icon = overlay.frontIcon
        let host = try #require(icon.superview)
        let inside = overlay.root.convert(
            NSPoint(x: icon.frame.midX, y: icon.frame.midY),
            from: host
        )
        #expect(overlay.frontHit(at: inside) == .appItem([WindowID(9)]))
        #expect(overlay.root.hitAt(inside) == .appItem([WindowID(9)]))
        #expect(overlay.frontHit(at: NSPoint(x: -50, y: -50)) == nil)
        // VoiceOver reads the rows per query, not from the render.
        let rows = "\(BarHit.appItem([WindowID(9)]))"
        #expect(icon.accessibilityCustomActions()?.map(\.name) == [rows])
        menus.rows = { _ in [.action("later") {}] }
        #expect(icon.accessibilityCustomActions()?.map(\.name) == ["later"])
        // The text glyph reads them live too.
        let glyph = SpaceBarItemView.App(
            name: "App9",
            icon: nil,
            glyph: "A",
            focused: false,
            count: 1,
            windows: [WindowID(9)]
        )
        show(overlay, front: glyph, style: style)
        menus.rows = { _ in [.action("again") {}] }
        #expect(
            overlay.frontGlyph.accessibilityCustomActions()?.map(\.name)
                == ["again"]
        )
        // A render with no front app forgets its windows.
        show(overlay, front: nil, style: style)
        #expect(overlay.frontWindows.isEmpty)
        #expect(overlay.frontMenuHit == .empty)
        withExtendedLifetime(menus) {}
    }

    private func show(
        _ overlay: SpaceBarOverlay,
        front: SpaceBarItemView.App?,
        style: SpaceBarLook
    ) {
        overlay.show(
            items: overlay.lastShown?.items ?? [],
            frontApp: front,
            strip: CGRect(x: 0, y: 0, width: 800, height: 32),
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
    }

    /// The chip's area is every drawn piece — box, glass, indicator,
    /// content — cut to the run that clips it.
    @Test("the chip's area unions what draws it, cut to its clip")
    func chipAreaUnionsAndClips() {
        let box = CGRect(x: 100, y: 0, width: 40, height: 30)
        let pad = CGRect(x: 90, y: 0, width: 60, height: 30)
        #expect(
            SpaceBarOverlay.chipArea([box, pad], clip: nil)
                == pad
        )
        #expect(
            SpaceBarOverlay.chipArea(
                [box, pad],
                clip: CGRect(x: 0, y: 0, width: 120, height: 30)
            ) == CGRect(x: 90, y: 0, width: 30, height: 30)
        )
        #expect(SpaceBarOverlay.chipArea([], clip: nil) == nil)
    }
}
