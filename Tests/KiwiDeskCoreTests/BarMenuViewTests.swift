import AppKit
import Testing

@testable import KiwiDeskCore

/// The bar views that answer a right-click (#1518), through a real
/// Space Bar overlay: each asks the one menu source for its hit, a
/// glyph answers nothing so its click reaches its chip, and
/// VoiceOver's actions read the same rows.
@Suite("Bar menu views", .serialized)
@MainActor
struct BarMenuViewTests {
    private let display = DisplayID(7)
    private let one = SpaceID("1")

    private var rightClick: NSEvent {
        NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    private func app(_ id: UInt32) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: "App\(id)",
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            focused: false,
            count: 1,
            windows: [WindowID(id)]
        )
    }

    /// A manager whose menu source answers each hit with one row
    /// naming it, and the overlay it drew Space 1 into.
    private func drawn() throws -> (
        menus: BarContextMenus, overlay: SpaceBarOverlay
    ) {
        let menus = BarContextMenus()
        menus.rows = { hit in [.action("\(hit)") {}] }
        let manager = SpaceBarManager()
        manager.contextMenus = menus
        let item = SpaceBarOverlay.Item(
            space: one,
            spaceGlyph: .text("1", tinted: true),
            apps: [app(2), app(3)],
            active: true,
            before: .init(windows: [WindowID(1)]),
            after: .init(windows: [WindowID(4)])
        )
        manager.sync([
            SpaceBarManager.Bar(
                display: display,
                items: [item],
                strip: CGRect(x: 0, y: 0, width: 800, height: 32),
                style: SpaceBarLook(),
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ])
        let overlay = try #require(manager.overlayForTesting(display))
        return (menus, overlay)
    }

    private func title(_ menu: NSMenu?) -> String? {
        menu?.items.first?.title
    }

    @Test("each view asks for its own hit")
    func viewsAskForTheirHit() throws {
        let (menus, overlay) = try drawn()
        defer { withExtendedLifetime(menus) {} }
        let chip = try #require(overlay.itemViews.first)
        #expect(title(chip.menu(for: rightClick)) == "\(BarHit.space(one))")
        let leading = try #require(chip.leadingTarget)
        let trailing = try #require(chip.overflowTarget)
        #expect(title(leading.menu(for: rightClick)) == "\(BarHit.disc(one))")
        #expect(title(trailing.menu(for: rightClick)) == "\(BarHit.disc(one))")
        #expect(title(overlay.backCount.menu(for: rightClick)) == "count")
        #expect(title(overlay.root.menu(for: rightClick)) == "empty")
    }

    /// A glyph has no menu of its own yet (#1518's window rows come
    /// later), so its click falls through to the chip under it —
    /// and VoiceOver on it hears the chip's rows, the same ones.
    @Test("a glyph answers nothing, so its chip does")
    func glyphFallsThrough() throws {
        let (menus, overlay) = try drawn()
        defer { withExtendedLifetime(menus) {} }
        let chip = try #require(overlay.itemViews.first)
        let glyph = try #require(chip.glyphTargets.first)
        #expect(glyph.menu(for: rightClick) == nil)
        #expect(
            glyph.accessibilityCustomActions()?.map(\.name)
                == ["\(BarHit.space(one))"]
        )
    }

    @Test("VoiceOver's actions on a chip are its menu's rows")
    func chipActionsAreItsRows() throws {
        let (menus, overlay) = try drawn()
        defer { withExtendedLifetime(menus) {} }
        let chip = try #require(overlay.itemViews.first)
        #expect(
            chip.accessibilityCustomActions()?.map(\.name)
                == ["\(BarHit.space(one))"]
        )
    }

    /// The shelf's own surfaces: the plate and strip outside both
    /// runs answer as empty bar space, the grip as the divider,
    /// and an App Bar section's background as empty space too.
    @Test("the shelf's surfaces answer for empty space and the divider")
    func shelfSurfaces() {
        let menus = BarContextMenus()
        menus.rows = { hit in [.action("\(hit)") {}] }
        let shelf = ShelfOverlay()
        shelf.contextMenus = menus
        // The panel build hosts the grip in the strip; no panel here.
        shelf.stripView.addSubview(shelf.handle)
        #expect(title(shelf.content.menu(for: rightClick)) == "empty")
        #expect(title(shelf.stripView.menu(for: rightClick)) == "empty")
        #expect(title(shelf.handle.menu(for: rightClick)) == "divider")
        let appBar = AppBarOverlay()
        appBar.contextMenus = menus
        #expect(title(appBar.root.menu(for: rightClick)) == "empty")
        #expect(title(appBar.forwardCount.menu(for: rightClick)) == "count")
    }

    private func click(_ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    /// A Control-click opens what a right-click would, found the
    /// same way: a glyph's is its chip's, a disc's its own; a plain
    /// click opens nothing, so the press does what it always did.
    @Test("a Control-click finds the right-click's menu")
    func controlClickFindsTheMenu() throws {
        let (menus, overlay) = try drawn()
        defer { withExtendedLifetime(menus) {} }
        let chip = try #require(overlay.itemViews.first)
        let glyph = try #require(chip.glyphTargets.first)
        let disc = try #require(chip.overflowTarget)
        #expect(
            title(glyph.controlClickMenu(click(.control)))
                == "\(BarHit.space(one))"
        )
        #expect(
            title(disc.controlClickMenu(click(.control)))
                == "\(BarHit.disc(one))"
        )
        #expect(glyph.controlClickMenu(click([])) == nil)
    }

    /// VoiceOver reaches the shelf section from an App Bar item and
    /// the front-app chip too (#1518), each finding the menu source
    /// through the surface above it.
    @Test("an App Bar item and the front-app chip speak the shelf")
    func appBarAndFrontChipSpeakTheShelf() throws {
        let menus = BarContextMenus()
        menus.rows = { hit in [.action("\(hit)") {}] }
        let surface = BarMenuView()
        surface.contextMenus = menus
        let item = AppBarItemView(frame: .zero)
        surface.addSubview(item)
        #expect(item.accessibilityCustomActions()?.map(\.name) == ["empty"])
        var style = SpaceBarLook()
        style.showFrontApp = true
        let manager = SpaceBarManager()
        manager.contextMenus = menus
        manager.sync([
            SpaceBarManager.Bar(
                display: display,
                items: [
                    SpaceBarOverlay.Item(
                        space: one,
                        spaceGlyph: .text("1", tinted: true),
                        apps: [],
                        active: true,
                        after: .none
                    )
                ],
                frontApp: app(9),
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
        let actions: [NSAccessibilityCustomAction]? =
            overlay.frontIcon.accessibilityCustomActions()
        #expect(actions?.map { $0.name } == ["empty"])
        // A text glyph fronts the chip where the app has one.
        var glyph = app(9)
        glyph = SpaceBarItemView.App(
            name: glyph.name,
            icon: nil,
            glyph: "A",
            focused: false,
            count: 1,
            windows: glyph.windows
        )
        overlay.show(
            items: overlay.lastShown?.items ?? [],
            frontApp: glyph,
            strip: CGRect(x: 0, y: 0, width: 800, height: 32),
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        let spoken: [NSAccessibilityCustomAction]? =
            overlay.frontGlyph.accessibilityCustomActions()
        #expect(spoken?.map { $0.name } == ["empty"])
    }
}
