import AppKit
import Testing

@testable import KiwiDeskCore

/// A scrolled, overflowing run takes a click and a hover on every
/// entry it shows (#1965): AppKit clips both an item's hit test
/// and its tracking area to the run's frame, so that frame must
/// hold every entry the viewport shows.
@Suite("Shelf run hit-testing", .serialized)
@MainActor
struct ShelfRunHitTests {
    init() { LiquidGlassGate.override = { false } }

    private static let strip = CGRect(x: 0, y: 0, width: 400, height: 28)

    /// Hit-tests `entry`'s centre at the clipping container, the
    /// way a click descends from the panel, after proving the
    /// entry is shown and lies wholly inside the run's frame.
    private func hit(
        _ entry: NSView,
        container: NSView,
        run: NSView
    ) throws -> NSView? {
        let parent = try #require(container.superview)
        let centre = NSPoint(x: entry.bounds.midX, y: entry.bounds.midY)
        let inContainer = entry.convert(centre, to: container)
        try #require(
            container.bounds.contains(inContainer),
            "the last entry is not on screen"
        )
        let inRun = entry.convert(entry.bounds, to: container)
        let slack = -ShelfOverflow.clipTolerance
        #expect(
            run.frame.insetBy(dx: slack, dy: slack).contains(inRun),
            "a shown entry overhangs the run: no click or hover"
        )
        return container.hitTest(entry.convert(centre, to: parent))
    }

    @Test("The App Bar's last entry takes a click and hover once scrolled")
    func appBarLastEntryHits() throws {
        let overlay = AppBarOverlay()
        let items = (1...10).map {
            AppBarOverlay.Item(
                id: WindowID(UInt32($0)),
                text: "Window \($0)",
                icon: nil
            )
        }
        overlay.show(
            items: items,
            activeIndex: items.count - 1,
            strip: Self.strip,
            style: AppBarLook(),
            capAxis: 2000
        )
        try #require(overlay.scrollOffset > 0, "the run did not scroll")
        let last = try #require(overlay.itemViews.last)
        let hit = try hit(
            last,
            container: overlay.itemContainer,
            run: overlay.itemRun
        )
        #expect(hit?.isDescendant(of: last) == true)
    }

    @Test("The Space Bar's last entry takes a click and hover once scrolled")
    func spaceBarLastEntryHits() throws {
        let overlay = SpaceBarOverlay()
        let items = (1...30).map { n in
            SpaceBarOverlay.Item(
                space: SpaceID(String(n)),
                spaceGlyph: .symbol("star"),
                apps: [],
                active: n == 30,
                after: .none
            )
        }
        var look = SpaceBarLook(
            shelf: KiwiShelf(),
            bar: SpaceBarStyle(),
            sheen: 0
        )
        look.shelf.liquidGlass = false
        overlay.show(
            items: items,
            strip: Self.strip,
            style: look,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        try #require(overlay.scrollOffset > 0, "the run did not scroll")
        let last = try #require(overlay.itemViews.last)
        let hit = try hit(
            last,
            container: overlay.itemContainer,
            run: overlay.itemRun
        )
        #expect(hit?.isDescendant(of: last) == true)
    }
}
