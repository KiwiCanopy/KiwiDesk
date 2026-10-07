import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The hover peek through the real Space Bar (#1946): the item's
/// hover reading reaches the shelf's one peek, the dwell opens it
/// with Core's content, and the pointer leaving, a one-window
/// glyph's pick, a strip scroll and its shelf leaving each close it.
@Suite("Bar hover peek wiring", .serialized)
@MainActor
struct BarPeekWiringTests {
    private let display = barTitleDisplay
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    init() {
        LiquidGlassGate.override = { false }
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    /// Space 1 active on Notes (1); Space 2 holds Web (4).
    private func seededCore() -> KiwiCore {
        let core = makeBarCore()
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(two)
        core.state.apply(
            .windowCreated(titledWindow(4, app: "Web", title: "Doc"))
        )
        core.state.workspaces.activate(one)
        core.state.apply(
            .windowCreated(titledWindow(1, app: "Notes", title: "Memo"))
        )
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    /// One render and placement, `updateBars`' order.
    private func render(_ core: KiwiCore) {
        var style = SpaceBarLook()
        style.liquidGlass = false
        let items = core.spaceBarItems(display: display, style: style)
        core.shelves.holdingRelayout {
            core.spaceBars.sync([
                SpaceBarManager.Bar(
                    display: display,
                    items: items,
                    strip: barTitleStrip,
                    style: style,
                    stateMarkColors: StateMarkColors(
                        sticky: "#ffffff",
                        floating: "#ffffff"
                    )
                )
            ])
        }
        core.shelves.sync([
            .init(
                display: display,
                edge: .top,
                strip: barTitleStrip,
                shelf: KiwiShelf(),
                sheen: 0,
                space: core.spaceBars.overlayForTesting(display),
                app: nil
            )
        ])
    }

    /// The rendered item for Space 2, its Web target, and a peek
    /// whose dwell is stepped by hand.
    private func hovered(
        _ core: KiwiCore,
        steps: Steps
    ) throws -> (SpaceBarItemView, SpaceBarGlyphTarget) {
        core.shelves.peek.schedule = { _, body in steps.queue.append(body) }
        render(core)
        let overlay = try #require(core.spaceBars.overlayForTesting(display))
        let item = try #require(overlay.itemViews.first { $0.space == two })
        let web = try #require(item.glyphTargets.first)
        let centre = web.convert(
            CGPoint(x: web.bounds.midX, y: web.bounds.midY),
            to: nil
        )
        BarHoverHit.pointerOverride = { _ in centre }
        item.syncHoverToPointer()
        return (item, web)
    }

    @MainActor
    final class Steps {
        var queue: [@MainActor () -> Void] = []
        func run() {
            let now = queue
            queue = []
            now.forEach { $0() }
        }
    }

    private func titles(_ core: KiwiCore) -> [String]? {
        core.shelves.peek.panel.drawn?.groups.flatMap(\.titles)
    }

    private func close(_ core: KiwiCore) {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    @Test("A resting pointer on a glyph opens its peek after the dwell")
    func hoverOpensAfterDwell() throws {
        let core = seededCore()
        let steps = Steps()
        defer { close(core) }
        _ = try hovered(core, steps: steps)
        #expect(titles(core) == nil, "nothing before the dwell")
        #expect(steps.queue.count == 1)
        steps.run()
        #expect(titles(core) == ["Doc"])
        #expect(core.shelves.peek.panel.drawn?.groups.map(\.app) == ["Web"])
    }

    @Test("The pointer leaving the item closes the peek")
    func exitCloses() throws {
        let core = seededCore()
        let steps = Steps()
        defer { close(core) }
        let (item, _) = try hovered(core, steps: steps)
        steps.run()
        try #require(titles(core) == ["Doc"], "was shown")
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
        item.syncHoverToPointer()
        #expect(titles(core) == nil)
    }

    /// A one-window glyph's click is a pick (#1946): the press
    /// leaves the peek, and the release picks through Core, which
    /// closes it and switches (#2044 picks on the release).
    @Test("A one-window glyph's release picks and closes the peek")
    func releasePicksAndCloses() throws {
        let core = seededCore()
        let steps = Steps()
        defer { close(core) }
        let (_, web) = try hovered(core, steps: steps)
        steps.run()
        try #require(titles(core) == ["Doc"], "was shown")
        let event = { (type: NSEvent.EventType) in
            NSEvent.mouseEvent(
                with: type,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        }
        web.mouseDown(with: try #require(event(.leftMouseDown)))
        #expect(titles(core) == ["Doc"], "the press keeps it")
        #expect(core.activeSpace?.id == one, "the press does not pick")
        web.mouseUp(with: try #require(event(.leftMouseUp)))
        #expect(titles(core) == nil, "the pick closes it")
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces.lastFocused == WindowID(4))
    }

    /// A shelf the bars stop drawing on — a fullscreen stand-down,
    /// the bars turned off, its display gone — takes its peek with
    /// it; the panel joins every Space and would stay up over the
    /// fullscreen app.
    @Test("A shelf leaving under a shown peek closes it")
    func shelfLeavingCloses() throws {
        let core = seededCore()
        let steps = Steps()
        defer { close(core) }
        _ = try hovered(core, steps: steps)
        steps.run()
        #expect(titles(core) == ["Doc"])
        core.shelves.sync([])
        #expect(titles(core) == nil)
    }

    @Test("A strip scroll closes the peek")
    func scrollCloses() throws {
        let core = seededCore()
        let steps = Steps()
        defer { close(core) }
        _ = try hovered(core, steps: steps)
        steps.run()
        try #require(titles(core) == ["Doc"], "was shown")
        let overlay = try #require(core.spaceBars.overlayForTesting(display))
        _ = overlay.root.onScroll(.init(x: 0, y: -4, precise: true))
        #expect(titles(core) == nil)
    }

    /// The shelf's relayout re-reads every hover and then checks the
    /// peek's item: an unmoved one keeps its peek.
    @Test("A relayout that leaves the item in place keeps the peek")
    func steadyRelayoutKeeps() throws {
        let core = seededCore()
        let steps = Steps()
        defer { close(core) }
        _ = try hovered(core, steps: steps)
        steps.run()
        render(core)
        #expect(titles(core) == ["Doc"])
    }
}
