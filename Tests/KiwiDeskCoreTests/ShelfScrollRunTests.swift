import AppKit
import Testing

@testable import KiwiDeskCore

/// A shelf section scrolls through its one scroll door (bars.md):
/// the run view moves alone — every item, and so every per-item
/// glass, keeps its frame — nothing re-renders, and what a render
/// derives from the offset is re-read to exactly a render's answer
/// at that offset. The parity clauses are the forget-proof half: a
/// new offset-dependent piece the door misses reds them. The door
/// re-lays the shelf only where the divider moved — leaving offset
/// 0 can — so the no-render clauses count from a scrolled start.
@Suite("Shelf scroll run")
@MainActor
struct ShelfScrollRunTests {
    init() { LiquidGlassGate.override = { false } }

    /// A trackpad scroll of `points` (negative scrolls forward).
    private func trackpad(_ points: Int32) throws -> NSEvent {
        let cg = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: points,
                wheel2: 0,
                wheel3: 0
            )
        )
        return try #require(NSEvent(cgEvent: cg))
    }

    /// What a section drew that depends on the offset.
    private struct Drawn: Equatable {
        let run: CGRect
        let before: Int
        let after: Int
        let mask: [NSNumber]?
        let plate: CGRect
        let content: CGRect
        let targets: [CGRect]
    }

    private func drawn(_ o: AppBarOverlay) -> Drawn {
        Drawn(
            run: o.itemRun.frame,
            before: o.backCount.count,
            after: o.forwardCount.count,
            mask: (o.itemContainer.layer?.mask as? CAGradientLayer)?
                .locations,
            plate: o.plateFrame,
            content: o.contentFrame,
            targets: []
        )
    }

    private func drawn(_ o: SpaceBarOverlay) -> Drawn {
        Drawn(
            run: o.itemRun.frame,
            before: o.backCount.count,
            after: o.forwardCount.count,
            mask: (o.itemContainer.layer?.mask as? CAGradientLayer)?
                .locations,
            plate: o.plateFrame,
            content: o.contentFrame,
            targets: o.hitFrames.map(\.frame)
        )
    }

    private func appBar() throws -> AppBarOverlay {
        let manager = AppBarManager()
        manager.sync([
            paintedAppBar(
                items: (1...60).map {
                    appBarItem(UInt32($0), text: "W\($0)")
                }
            )
        ])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    private func spaceBar(spaces: Int = 60) throws -> SpaceBarOverlay {
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: nil, spaces: spaces)])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    @Test("An App Bar scroll moves the run and draws a render's answer")
    func appBarScroll() throws {
        let overlay = try appBar()
        let frames = overlay.itemViews.map(\.frame)
        let item = try #require(overlay.itemViews.first)
        item.scrollWheel(with: try trackpad(-100))
        let first = overlay.scrollOffset
        var renders = 0
        overlay.onRendered = { renders += 1 }
        item.scrollWheel(with: try trackpad(-300))
        let offset = overlay.scrollOffset
        #expect(offset > first)
        #expect(overlay.itemViews.map(\.frame) == frames)
        #expect(overlay.itemRun.frame.minX == -offset)
        #expect(renders == 0)
        let scrolled = drawn(overlay)
        #expect(scrolled.before > 0)
        overlay.render(followingFocus: false)
        #expect(overlay.scrollOffset == offset)
        #expect(drawn(overlay) == scrolled)
    }

    @Test("An App Bar page takes the scroll door")
    func appBarPage() throws {
        let overlay = try appBar()
        _ = overlay.scroll(
            ShelfScrollInput.Delta(x: 0, y: -100, precise: true)
        )
        let first = overlay.scrollOffset
        var renders = 0
        overlay.onRendered = { renders += 1 }
        overlay.forwardCount.onPage()
        #expect(overlay.scrollOffset > first)
        #expect(renders == 0)
        let paged = drawn(overlay)
        overlay.render(followingFocus: false)
        #expect(drawn(overlay) == paged)
    }

    @Test("A Space Bar scroll moves the run and draws a render's answer")
    func spaceBarScroll() throws {
        let overlay = try spaceBar()
        let frames = overlay.itemViews.map(\.frame)
        let item = try #require(overlay.itemViews.first)
        item.scrollWheel(with: try trackpad(-100))
        let first = overlay.scrollOffset
        let targets = overlay.hitFrames.map(\.frame)
        var renders = 0
        overlay.onRendered = { renders += 1 }
        item.scrollWheel(with: try trackpad(-300))
        let offset = overlay.scrollOffset
        #expect(offset > first)
        #expect(overlay.itemViews.map(\.frame) == frames)
        #expect(overlay.itemRun.frame.minX == -offset)
        #expect(renders == 0)
        // A target still whole on both sides of the scroll moved
        // back by exactly the travel.
        let travel = offset - first
        let moved = overlay.hitFrames.first { now in
            targets.contains { abs($0.maxX - travel - now.frame.maxX) < 0.01 }
        }
        #expect(moved != nil)
        let scrolled = drawn(overlay)
        #expect(scrolled.before > 0)
        overlay.render(followingActive: false)
        #expect(overlay.scrollOffset == offset)
        #expect(drawn(overlay) == scrolled)
    }

    /// A front segment too long to pin scrolls with the run (#409):
    /// its name is cut at the viewport's end (#1763), so the scroll
    /// door re-lays it — scrolled to the end the whole name shows,
    /// as a render at that offset draws it.
    @Test("An unpinned front name follows the scroll")
    func unpinnedFrontNameIsWhole() throws {
        let manager = SpaceBarManager()
        let base = paintedSpaceBar(front: WindowID(1), spaces: 60)
        var front = try #require(base.frontApp)
        front.title = String(repeating: "A long title ", count: 40)
        manager.sync([
            SpaceBarManager.Bar(
                display: base.display,
                items: base.items,
                frontApp: front,
                frontWindow: base.frontWindow,
                strip: base.strip,
                style: base.style,
                stateMarkColors: base.stateMarkColors
            )
        ])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        try #require(
            overlay.frontName.superview === overlay.itemRun,
            "the segment is pinned, not scrolling with the run"
        )
        let name = overlay.frontName
        let full = name.fittingSize.width
        try #require(name.frame.width < full, "the fixture must cut")
        overlay.moveRun(to: .greatestFiniteMagnitude, animated: false)
        #expect(abs(name.frame.width - full) < 1)
        let scrolled = name.frame
        overlay.render(followingActive: false)
        #expect(name.frame == scrolled)
    }

    @Test("A Space Bar page and autoscroll step take the scroll door")
    func spaceBarPageAndStep() throws {
        // Long enough that the page stays mid-run: an end coming
        // into view moves the divider and rightly re-lays the shelf.
        let overlay = try spaceBar(spaces: 200)
        _ = overlay.scroll(
            ShelfScrollInput.Delta(x: 0, y: -100, precise: true)
        )
        var renders = 0
        overlay.onRendered = { renders += 1 }
        overlay.forwardCount.onPage()
        let paged = overlay.scrollOffset
        #expect(paged > 0)
        overlay.scroll(by: -40)
        #expect(overlay.scrollOffset == paged - 40)
        #expect(renders == 0)
        let stepped = drawn(overlay)
        overlay.render(followingActive: false)
        #expect(drawn(overlay) == stepped)
    }
}
