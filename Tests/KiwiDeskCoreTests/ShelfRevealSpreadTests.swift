import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The Boxed unfold and grow (owner ruling 2026-10-21): with no
/// plate, an unfold springs each box — its glass host, never the
/// glass — out of the mark to its slot, the farther later, and
/// gathers the outer first; a grow plays that spread (#2556).
/// Main-actor spend: a few overlays,
/// one ordered panel each.
@Suite("Shelf reveal spread", .serialized)
@MainActor
struct ShelfRevealSpreadTests {
    private static let mark = CGRect(x: 470, y: 0, width: 60, height: 8)
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)
    private static let near = CGRect(x: 480, y: 4, width: 40, height: 32)
    private static let far = CGRect(x: 200, y: 4, width: 40, height: 32)

    /// A section of two box hosts and a count beside them.
    @MainActor
    private struct Run {
        let view = NSView(frame: ShelfRevealSpreadTests.strip)
        let near = GlassBoxHost(frame: ShelfRevealSpreadTests.near)
        let far = GlassBoxHost(frame: ShelfRevealSpreadTests.far)
        let count = NSView(frame: CGRect(x: 600, y: 4, width: 20, height: 32))
        let hidden = GlassBoxHost(frame: ShelfRevealSpreadTests.far)

        init() {
            view.frame.origin = .zero
            for box in [near, far, count, hidden] {
                box.wantsLayer = true
                view.addSubview(box)
            }
            hidden.isHidden = true
        }
    }

    /// A shown Boxed shelf whose reveal is `style`.
    private func overlay(
        _ style: KiwiShelf.RevealStyle,
        run: Run
    ) -> ShelfOverlay {
        let overlay = ShelfOverlay()
        overlay.afterReveal = { _, _ in }
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.backgroundStyle = .boxed
        shelf.revealStyle = style
        let span = Self.far.union(Self.near)
        overlay.show(
            strip: Self.strip,
            edge: .top,
            shelf: shelf,
            sheen: 0,
            sections: [
                .init(
                    view: run.view,
                    slot: Self.strip,
                    plate: span,
                    content: span
                )
            ]
        )
        overlay.revealMark = .init(frame: Self.mark)
        return overlay
    }

    private func motion(_ view: NSView) -> CAAnimation? {
        view.layer?.animation(forKey: BarMotion.revealKey)
    }

    @Test("A spread moves each box host and fades what holds none")
    func unitsAreTheHosts() {
        let run = Run()
        let (boxes, still) = BarMotion.spreadUnits(in: run.view)
        #expect(boxes.count == 2)
        #expect(boxes.contains { $0 === run.near })
        #expect(boxes.contains { $0 === run.far })
        #expect(still.count == 1 && still.first === run.count)
    }

    /// Under Reduce Motion, which the owner ruled keeps the reveal.
    @Test("Boxes spring out of the mark, the farther later")
    func revealSpreadsByDistance() throws {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let run = Run()
        let overlay = overlay(.unfold, run: run)
        defer { overlay.hide() }
        overlay.revealIn()
        let near = try #require(motion(run.near) as? CAAnimationGroup)
        let far = try #require(motion(run.far) as? CAAnimationGroup)
        #expect(far.beginTime > near.beginTime)
        let spring = try #require(
            far.animations?.first { $0 is CASpringAnimation }
                as? CASpringAnimation
        )
        #expect(spring.keyPath == "transform")
        let start = try #require(
            (spring.fromValue as? NSValue)?.caTransform3DValue
        )
        #expect(!CATransform3DIsIdentity(start))
        #expect(
            CATransform3DIsIdentity(
                try #require((spring.toValue as? NSValue)?.caTransform3DValue)
            )
        )
        #expect(motion(run.count) != nil)
        // The content is never clipped: no plate draws.
        #expect(motion(overlay.content) == nil)
        #expect(!overlay.growing)
    }

    @Test("A gather takes the outer boxes first")
    func retractGathersOuterFirst() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let run = Run()
        let overlay = overlay(.unfold, run: run)
        defer { overlay.hide() }
        #expect(overlay.retractOut())
        let near = try #require(motion(run.near))
        let far = try #require(motion(run.far))
        #expect(far.beginTime < near.beginTime)
    }

    @Test("A landing clears a box hidden mid-spread too")
    func landingClearsHiddenBoxes() {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let run = Run()
        let overlay = overlay(.unfold, run: run)
        defer { overlay.hide() }
        overlay.revealIn()
        #expect(motion(run.near) != nil)
        run.near.isHidden = true
        BarMotion.endReveal(overlay.content, items: overlay.stripView)
        #expect(motion(run.near) == nil)
        #expect(motion(run.far) == nil)
    }

    /// Grow's wipe never retracted on a Boxed shelf, so it plays
    /// the spread there (#2556).
    @Test("A Boxed grow plays the spread")
    func boxedGrowSpreads() {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let run = Run()
        let overlay = overlay(.grow, run: run)
        defer { overlay.hide() }
        overlay.revealIn()
        #expect(motion(run.near) != nil)
        #expect(motion(run.far) != nil)
        #expect(!(motion(overlay.content) is CAAnimationGroup))
    }
}
