import AppKit
import Testing

@testable import KiwiDeskCore

/// The fade as the bar managers and the shelf manager drive it
/// (#1838): a manager's hide tears nothing down and a hide of a
/// hidden section writes nothing, a refresh inside the fade leaves
/// the leaving root shown, and the shelf manager keeps a leaving
/// shelf until it has left — naming its display as leaving
/// meanwhile — then retires it.
@Suite("Shelf fade through the managers", .serialized)
@MainActor
struct ShelfFadeManagerTests {
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

    @Test("A shelf never shown reports leaving at once")
    func neverShownLeaves() {
        let overlay = ShelfOverlay()
        var left = 0
        overlay.onLeft = { left += 1 }
        overlay.hide(animated: true)
        #expect(left == 1)
        #expect(!overlay.isVisible)
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
