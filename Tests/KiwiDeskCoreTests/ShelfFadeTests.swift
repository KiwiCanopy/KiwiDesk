import AppKit
import Testing

@testable import KiwiDeskCore

/// A shelf on an edge of its own fades in where it appears and
/// fades out where it leaves (#1838, owner ruling): the panel
/// stays until the fade-out lands, a show meanwhile keeps it, and
/// the shelf reports that it has left exactly once — at once
/// without a fade, else when the fade lands.
@Suite("Shelf fade", .serialized)
@MainActor
struct ShelfFadeTests {
    private static let strip = CGRect(x: 100, y: 0, width: 1000, height: 40)

    private static func shelf() -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        return shelf
    }

    private static func section() -> ShelfOverlay.Section {
        .init(
            view: NSView(),
            slot: strip,
            plate: CGRect(x: 0, y: 0, width: 1000, height: 40),
            content: CGRect(x: 10, y: 0, width: 980, height: 40)
        )
    }

    private func show(_ overlay: ShelfOverlay, _ section: ShelfOverlay.Section)
    {
        overlay.show(
            strip: Self.strip,
            edge: .top,
            shelf: Self.shelf(),
            sheen: 0,
            sections: [section]
        )
    }

    /// Polls `done` on the main actor, bounded generously (#344).
    private func settle(until done: () -> Bool) async throws {
        for _ in 0..<150 where !done() {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("An instant hide leaves at once and reports it once")
    func instantHide() {
        let overlay = ShelfOverlay()
        var left = 0
        overlay.onLeft = { left += 1 }
        show(overlay, Self.section())
        #expect(overlay.isVisible)
        overlay.hide()
        #expect(!overlay.isVisible)
        #expect(left == 1)
    }

    @Test("A fading hide keeps the panel until the fade lands")
    func fadingHide() async throws {
        pinShelfGlide()
        let overlay = ShelfOverlay()
        var left = 0
        overlay.onLeft = { left += 1 }
        show(overlay, Self.section())
        overlay.hide(animated: true)
        if !BarMotion.isReduced {
            #expect(overlay.isVisible)
            #expect(left == 0)
        }
        try await settle { left == 1 }
        #expect(!overlay.isVisible)
        #expect(left == 1)
    }

    @Test("A show during the fade-out keeps the shelf")
    func showCancelsTheFade() async throws {
        guard !BarMotion.isReduced else { return }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        var left = 0
        overlay.onLeft = { left += 1 }
        let section = Self.section()
        show(overlay, section)
        overlay.hide(animated: true)
        show(overlay, section)
        try await Task.sleep(for: .milliseconds(300))
        #expect(overlay.isVisible)
        #expect(left == 0)
    }

    /// Every bar refresh inside the glide asks the unwanted shelf
    /// to hide again; a restarted fade never landed on a lively
    /// Space (device, #1838).
    @Test("A hide already fading keeps its landing")
    func repeatedHideKeepsTheLanding() async throws {
        guard !BarMotion.isReduced else { return }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        var left = 0
        overlay.onLeft = { left += 1 }
        show(overlay, Self.section())
        #expect(overlay.hide(animated: true))
        // Asked again mid-fade, the running fade is kept.
        #expect(!overlay.hide(animated: true))
        try await settle { left == 1 }
        #expect(left == 1)
        #expect(!overlay.isVisible)
    }

    /// A section wanted again before its leave lands stays on the
    /// strip; the landing removing it re-joined it a second time
    /// (device, #1838).
    @Test("A section wanted again before its leave lands stays")
    func reWantedSectionStays() async throws {
        guard !BarMotion.isReduced else { return }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        let space = ShelfOverlay.Section(
            view: NSView(),
            slot: CGRect(x: 100, y: 0, width: 500, height: 40),
            plate: CGRect(x: 0, y: 0, width: 500, height: 40),
            content: CGRect(x: 10, y: 0, width: 480, height: 40)
        )
        let app = ShelfOverlay.Section(
            view: NSView(),
            slot: CGRect(x: 620, y: 0, width: 400, height: 40),
            plate: CGRect(x: 0, y: 0, width: 400, height: 40),
            content: CGRect(x: 10, y: 0, width: 380, height: 40)
        )
        let both = { (sections: [ShelfOverlay.Section]) in
            overlay.show(
                strip: Self.strip,
                edge: .top,
                shelf: Self.shelf(),
                sheen: 0,
                sections: sections
            )
        }
        var landings: [@MainActor () -> Void] = []
        overlay.afterGlide = { landings.append($0) }
        both([space, app])
        both([space])
        #expect(overlay.leavingViews[app.view] != nil)
        both([space, app])
        #expect(overlay.leavingViews[app.view] == nil)
        // The leave's landing, run by hand.
        try #require(landings.count == 1)
        landings[0]()
        #expect(app.view.superview === overlay.stripView)
    }

    /// A section that leaves, is wanted again and leaves again inside
    /// one glide wears its latest leave's stamp: the first landing
    /// leaves it to the second, which removes it (#1838).
    @Test("A leave inside a leave keeps the later landing")
    func leaveInsideALeave() throws {
        guard !BarMotion.isReduced else { return }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        var landings: [@MainActor () -> Void] = []
        overlay.afterGlide = { landings.append($0) }
        let space = ShelfOverlay.Section(
            view: NSView(),
            slot: CGRect(x: 100, y: 0, width: 500, height: 40),
            plate: CGRect(x: 0, y: 0, width: 500, height: 40),
            content: CGRect(x: 10, y: 0, width: 480, height: 40)
        )
        let app = ShelfOverlay.Section(
            view: NSView(),
            slot: CGRect(x: 620, y: 0, width: 400, height: 40),
            plate: CGRect(x: 0, y: 0, width: 400, height: 40),
            content: CGRect(x: 10, y: 0, width: 380, height: 40)
        )
        let both = { (sections: [ShelfOverlay.Section]) in
            overlay.show(
                strip: Self.strip,
                edge: .top,
                shelf: Self.shelf(),
                sheen: 0,
                sections: sections
            )
        }
        both([space, app])
        both([space])
        let first = try #require(overlay.leavingViews[app.view])
        both([space, app])
        both([space])
        let second = try #require(overlay.leavingViews[app.view])
        #expect(second != first)
        try #require(landings.count == 2)
        // The first leave's landing leaves the view to the second.
        landings[0]()
        #expect(app.view.superview === overlay.stripView)
        #expect(overlay.leavingViews[app.view] == second)
        landings[1]()
        #expect(app.view.superview == nil)
        #expect(overlay.leavingViews.isEmpty)
    }

    /// The Space Bar's twin of the hide contract.
    @Test("A hidden Space Bar section keeps its views, hides once")
    func hiddenSpaceBarSectionKeepsItsViews() {
        let overlay = SpaceBarOverlay()
        overlay.show(
            items: paintedSpaceBar(front: nil, spaces: 2).items,
            strip: Self.strip,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        overlay.hide()
        #expect(overlay.root.isHidden)
        #expect(!overlay.itemViews.isEmpty)
        #expect(
            overlay.itemViews.allSatisfy { $0.superview === overlay.itemRun }
        )
        overlay.root.isHidden = false
        overlay.hide()
        #expect(!overlay.root.isHidden)
    }

    /// The bar managers hide a section and tear nothing down, and a
    /// hide of a hidden section writes nothing: the shelf shows the
    /// root again while the leave runs, and every refresh inside
    /// the glide asks the manager to hide once more (#1838).
    @Test("A hidden section keeps its views; a second hide writes nothing")
    func hiddenSectionKeepsItsViews() {
        let overlay = AppBarOverlay()
        overlay.show(
            items: [AppBarOverlay.Item(id: WindowID(1), text: "A", icon: nil)],
            activeIndex: nil,
            strip: Self.strip,
            style: AppBarLook(),
            space: SpaceID("1")
        )
        overlay.hide()
        #expect(overlay.root.isHidden)
        #expect(!overlay.itemViews.isEmpty)
        #expect(
            overlay.itemViews.allSatisfy { $0.superview === overlay.itemRun }
        )
        overlay.root.isHidden = false
        overlay.hide()
        #expect(!overlay.root.isHidden)
    }

    /// Driven through the managers: a refresh inside the fade asks
    /// the App Bar manager to hide again, and the leaving root stays
    /// shown until the fade lands.
    @Test("A refresh inside the fade keeps the leaving section shown")
    func refreshKeepsTheLeavingSection() async throws {
        guard !BarMotion.isReduced else { return }
        pinShelfGlide()
        let apps = AppBarManager()
        let bar = AppBarManager.Bar(
            display: barTitleDisplay,
            space: SpaceID("1"),
            items: [AppBarOverlay.Item(id: WindowID(1), text: "A", icon: nil)],
            activeIndex: nil,
            strip: barTitleStrip,
            style: AppBarLook(),
            capAxis: barTitleStrip.width
        )
        apps.sync([bar])
        let app = try #require(apps.shownOverlay(on: barTitleDisplay))
        let shelves = ShelfManager()
        shelves.sync([
            ShelfManager.Shelf(
                display: barTitleDisplay,
                edge: .bottom,
                strip: barTitleStrip,
                shelf: Self.shelf(),
                sheen: 0,
                space: nil,
                app: app
            )
        ])
        apps.sync([])
        shelves.sync([])
        #expect(!app.root.isHidden)
        apps.sync([])
        #expect(!app.root.isHidden)
        try await settle { shelves.overlayForTesting(barTitleDisplay) == nil }
        #expect(shelves.overlayForTesting(barTitleDisplay) == nil)
    }

    @Test("A shelf never shown reports leaving at once")
    func neverShownLeaves() {
        let overlay = ShelfOverlay()
        var left = 0
        overlay.onLeft = { left += 1 }
        overlay.hide(animated: true)
        #expect(left == 1)
        #expect(!overlay.isVisible)
    }

    /// The manager keeps a leaving shelf until it has left, then
    /// drops it.
    @Test("The manager retires a shelf once it has left")
    func managerRetiresOnceLeft() async throws {
        pinShelfGlide()
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        let shelves = ShelfManager()
        shelves.sync([
            ShelfManager.Shelf(
                display: barTitleDisplay,
                edge: .top,
                strip: barTitleStrip,
                shelf: Self.shelf(),
                sheen: 0,
                space: section,
                app: nil
            )
        ])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        shelves.sync([])
        if !BarMotion.isReduced {
            #expect(shelves.overlayForTesting(barTitleDisplay) === overlay)
            // Its display is spared by the bar managers' retire
            // while the fade runs.
            #expect(shelves.leavingDisplays == [barTitleDisplay])
        }
        try await settle { shelves.overlayForTesting(barTitleDisplay) == nil }
        #expect(shelves.overlayForTesting(barTitleDisplay) == nil)
        #expect(shelves.leavingDisplays.isEmpty)
        #expect(!overlay.isVisible)
    }
}
