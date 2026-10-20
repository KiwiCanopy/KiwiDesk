import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The ORDER a hiding shelf's reveal starts in (#761, #2497), split
/// from `ShelfRevealMotionTests` at the §2.1 target: the pass
/// ordering the panel in holds the slide, a shown panel's starts at
/// once, a retract slides back out, Reduce Motion cross-fades, and
/// the reveal delay redraws once. Main-actor spend: a few overlays,
/// one ordered panel each.
@Suite("Shelf reveal start order (#761)", .serialized)
@MainActor
struct ShelfRevealStartTests {
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)

    /// A shown shelf, its reveal landings swallowed.
    private func overlay() -> ShelfOverlay {
        let overlay = ShelfOverlay()
        overlay.afterReveal = { _, _ in }
        let plate = CGRect(x: 200, y: 0, width: 300, height: 40)
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        overlay.show(
            strip: Self.strip,
            edge: .top,
            shelf: shelf,
            sheen: 0,
            sections: [
                .init(
                    view: NSView(),
                    slot: Self.strip,
                    plate: plate,
                    content: plate
                )
            ]
        )
        return overlay
    }

    private func motion(_ view: NSView) -> CAAnimation? {
        view.layer?.animation(forKey: BarMotion.revealKey)
    }

    @Test("A reveal ordering the panel in holds the slide a pass")
    func orderingRevealWaitsForTheCommit() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay()
        defer { overlay.hide() }
        var commits: [() -> Void] = []
        overlay.afterCommit = { commits.append($0) }
        overlay.revealIn(ordering: true)
        // No mask is rendered off screen per frame: the panel clips.
        #expect(overlay.content.layer?.mask == nil)
        #expect(motion(overlay.content)?.speed == 0)
        #expect(motion(overlay.stripView) == nil)
        #expect(commits.count == 1)
        commits.first?()
        let slide = try #require(motion(overlay.content))
        #expect(slide.speed == 1)
        #expect(slide.beginTime > 0)
    }

    @Test("A retract slides back out past the screen side")
    func retractSlidesOut() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay()
        defer { overlay.hide() }
        #expect(overlay.retractOut())
        let slide = try #require(
            motion(overlay.content) as? CABasicAnimation
        )
        #expect(slide.keyPath == "position")
        let end = try #require(slide.toValue as? NSValue).pointValue
        #expect(abs(end.y) == Self.strip.height)
    }

    @Test("Under Reduce Motion a reveal fades the content in place")
    func reducedRevealFades() throws {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay()
        defer { overlay.hide() }
        overlay.revealIn()
        let fade = try #require(
            motion(overlay.content) as? CABasicAnimation
        )
        #expect(fade.keyPath == "opacity")
    }

    @Test("A reveal on a shown panel starts at once")
    func shownRevealStartsAtOnce() {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay()
        defer { overlay.hide() }
        var commits = 0
        overlay.afterCommit = { _ in commits += 1 }
        overlay.revealIn()
        #expect(motion(overlay.content)?.speed == 1)
        #expect(commits == 0)
    }

    @Test("The reveal delay ends the hover in the reveal's own pass")
    func revealEndsTheHoverInOnePass() {
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
            bar: .space
        )
        let revealer = ShelfRevealer()
        var timers: [() -> Void] = []
        let point = CGPoint(x: 500, y: 770)
        var changes: [(Bool, Bool)] = []
        revealer.makeMonitor = { _ in nil }
        revealer.location = { point }
        revealer.schedule = { _, body in
            timers.append(body)
            return ShelfRevealTimer()
        }
        revealer.onChange = {
            changes.append(
                (
                    revealer.arming.contains(key),
                    revealer.reveal(of: key).isShown
                )
            )
        }
        revealer.sync([
            key: ShelfRevealer.Target.hovering(
                edge: .top,
                strip: CGRect(x: 0, y: 735, width: 1000, height: 40),
                screen: CGRect(x: 0, y: 0, width: 1000, height: 800)
            )
        ])
        revealer.moved(to: point)
        #expect(changes.map(\.0) == [true])
        changes = []
        timers.removeFirst()()
        // One redraw, already shown: no pass un-hovers the plate
        // first.
        #expect(changes.count == 1)
        #expect(changes.first?.0 == false)
        #expect(changes.first?.1 == true)
    }
}
