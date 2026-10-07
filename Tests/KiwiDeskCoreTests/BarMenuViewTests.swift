import AppKit
import Testing

@testable import KiwiDeskCore

/// The bar views that answer a right-click (#1518), through a real
/// Space Bar overlay: each asks the one menu source for its hit, a
/// glyph and an App Bar item for the windows they stand for, and
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

    /// A glyph asks for its own window rows, naming the windows
    /// it stands for, and VoiceOver on it hears the same rows.
    @Test("a glyph asks for the windows it stands for")
    func glyphNamesItsWindows() throws {
        let (menus, overlay) = try drawn()
        defer { withExtendedLifetime(menus) {} }
        let chip = try #require(overlay.itemViews.first)
        let glyph = try #require(chip.glyphTargets.first)
        let hit = "\(BarHit.glyph([WindowID(2)]))"
        #expect(title(glyph.menu(for: rightClick)) == hit)
        #expect(glyph.accessibilityCustomActions()?.map(\.name) == [hit])
    }

    /// An App Bar item hands its menu the windows the RENDER gave
    /// it — a collapsed group's, not only the item's own id.
    @Test("an App Bar item asks for its group's windows")
    func appBarItemNamesItsGroup() throws {
        let menus = BarContextMenus()
        menus.rows = { hit in [.action("\(hit)") {}] }
        let appBar = AppBarOverlay()
        appBar.contextMenus = menus
        appBar.show(
            items: [
                AppBarOverlay.Item(
                    id: WindowID(2),
                    text: "A",
                    icon: nil,
                    count: 2,
                    members: [WindowID(2), WindowID(3)]
                )
            ],
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 800, height: 32),
            style: AppBarLook()
        )
        let item = try #require(appBar.itemViews.first)
        let hit = "\(BarHit.appItem([WindowID(2), WindowID(3)]))"
        #expect(title(item.menu(for: rightClick)) == hit)
        #expect(item.accessibilityCustomActions()?.map(\.name) == [hit])
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
    /// same way: a glyph's and a disc's their own; a plain
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
                == "\(BarHit.glyph([WindowID(2)]))"
        )
        #expect(
            title(disc.controlClickMenu(click(.control)))
                == "\(BarHit.disc(one))"
        )
        #expect(glyph.controlClickMenu(click([])) == nil)
    }

    /// VoiceOver reaches an App Bar item's rows and the front-app
    /// chip's window rows (#1518, #2024), each finding the menu
    /// source through the surface above it.
    @Test("an App Bar item and the front-app chip speak their rows")
    func appBarAndFrontChipSpeakTheShelf() throws {
        let menus = BarContextMenus()
        menus.rows = { hit in [.action("\(hit)") {}] }
        let surface = BarMenuView()
        surface.contextMenus = menus
        let item = AppBarItemView(frame: .zero)
        surface.addSubview(item)
        #expect(
            item.accessibilityCustomActions()?.map(\.name)
                == ["\(BarHit.appItem([]))"]
        )
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
        // The chip speaks its window's rows (#2024).
        let front = "\(BarHit.appItem([WindowID(9)]))"
        #expect(actions?.map { $0.name } == [front])
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
        #expect(spoken?.map { $0.name } == [front])
    }
}
