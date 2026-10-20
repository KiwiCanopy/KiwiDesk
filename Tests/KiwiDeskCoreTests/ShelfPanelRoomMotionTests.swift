import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The shelf panel's room while something moves (#2497), split from
/// `ShelfPanelRoomTests`: a plate glide holds both of its ends, a
/// slide the room out to the usable area's edge, and each landing
/// shrinks it back to the plate; a reveal a leave cut short never
/// keeps it open.
@Suite("Shelf panel room in motion (#2497)", .serialized)
@MainActor
struct ShelfPanelRoomMotionTests {
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)
    private static let margin: CGFloat = 6

    private static func shelf() -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.backgroundFit = .hug
        shelf.outerMargin = margin
        return shelf
    }

    private static func plate(at x: CGFloat) -> CGRect {
        CGRect(x: x, y: 0, width: 300, height: 40)
    }

    private static func section(
        _ view: NSView,
        plate: CGRect
    ) -> ShelfOverlay.Section {
        .init(view: view, slot: strip, plate: plate, content: plate)
    }

    /// `rect` in strip coordinates as the panel's Cocoa frame.
    private static func onScreen(_ rect: CGRect) -> CGRect {
        GeometryUtils.flip(
            rect.offsetBy(dx: strip.minX, dy: strip.minY),
            primaryHeight: GeometryUtils.primaryHeight
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

    @Test("A plate glide holds both of its ends until it lands")
    func glideHoldsBothEnds() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        var landings: [() -> Void] = []
        overlay.afterGlide = { landings.append($0) }
        let view = NSView()
        show(overlay, Self.section(view, plate: Self.plate(at: 200)))
        let panel = try #require(overlay.panel)
        try #require(landings.isEmpty, "a first show glides nothing")
        show(overlay, Self.section(view, plate: Self.plate(at: 600)))
        try #require(landings.count == 1)
        let both = Self.plate(at: 200).union(Self.plate(at: 600))
        #expect(panel.frame == Self.onScreen(both))
        landings[0]()
        #expect(panel.frame == Self.onScreen(Self.plate(at: 600)))
    }

    @Test("A slide opens the room to the usable edge until it lands")
    func slideHoldsTheMargin() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        var landings: [() -> Void] = []
        overlay.afterReveal = { _, body in landings.append(body) }
        overlay.afterCommit = { $0() }
        overlay.slides = true
        show(overlay, Self.section(NSView(), plate: Self.plate(at: 200)))
        let panel = try #require(overlay.panel)
        try #require(landings.count == 1)
        // Run out over the outer margin, up to the usable edge.
        let travel = CGRect(
            x: 200,
            y: -Self.margin,
            width: 300,
            height: 40 + Self.margin
        )
        #expect(panel.frame == Self.onScreen(travel))
        landings[0]()
        #expect(panel.frame == Self.onScreen(Self.plate(at: 200)))
    }

    /// A reveal a non-sliding fade-out cut short lands nowhere; the
    /// next show still settles on the plate.
    @Test("A reveal cut short by a fade keeps no room open")
    func cutRevealSettles() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        var glides: [() -> Void] = []
        overlay.afterGlide = { glides.append($0) }
        overlay.afterReveal = { _, _ in }
        overlay.afterCommit = { $0() }
        overlay.slides = true
        let view = NSView()
        show(overlay, Self.section(view, plate: Self.plate(at: 200)))
        overlay.slides = false
        overlay.hide(animated: true)
        for landing in glides { landing() }
        show(overlay, Self.section(view, plate: Self.plate(at: 200)))
        let panel = try #require(overlay.panel)
        #expect(panel.frame == Self.onScreen(Self.plate(at: 200)))
    }

    @Test("A slide starts the content wholly past the screen side")
    func slideStartsOffTheEdge() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        overlay.afterReveal = { _, _ in }
        var commits: [() -> Void] = []
        overlay.afterCommit = { commits.append($0) }
        overlay.slides = true
        show(overlay, Self.section(NSView(), plate: Self.plate(at: 200)))
        #expect(
            overlay.revealOffset
                == CGVector(dx: 0, dy: -(Self.strip.height + Self.margin))
        )
        let held = try #require(
            overlay.content.layer?.animation(forKey: BarMotion.revealKey)
                as? CABasicAnimation
        )
        #expect(held.keyPath == "position")
        #expect(held.isAdditive)
        #expect(held.speed == 0)
        let start = try #require(held.fromValue as? NSValue).pointValue
        #expect(abs(start.y) == Self.strip.height + Self.margin)
        try #require(commits.count == 1)
        commits[0]()
        let moving = try #require(
            overlay.content.layer?.animation(forKey: BarMotion.revealKey)
        )
        #expect(moving.speed == 1)
        #expect(moving.beginTime > 0)
    }
}
