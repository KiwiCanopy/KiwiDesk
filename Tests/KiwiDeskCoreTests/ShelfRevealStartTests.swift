import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The ORDER a hiding shelf's reveal starts in (#761), split from
/// `ShelfRevealMotionTests` at the §2.1 target: the pass ordering
/// the panel in holds both channels, the plate leads the items in
/// and follows them out, a Boxed shelf only fades, and the reveal
/// delay redraws once. Main-actor spend: unwindowed overlays.
@Suite("Shelf reveal start order (#761)")
@MainActor
struct ShelfRevealStartTests {
    private static let mark = CGRect(x: 100, y: 0, width: 60, height: 8)
    private static let plate = CGRect(x: 20, y: 0, width: 360, height: 40)

    private func overlay(plate: Bool) -> ShelfOverlay {
        let overlay = ShelfOverlay()
        overlay.afterReveal = { _, _ in }
        overlay.content.frame = CGRect(x: 0, y: 0, width: 400, height: 40)
        overlay.revealOrigin = Self.mark
        overlay.revealPlate = plate ? (Self.plate, 10) : nil
        return overlay
    }

    private func motion(_ view: NSView) -> CAAnimation? {
        view.layer?.animation(forKey: BarMotion.revealKey)
    }

    @Test("A reveal ordering the panel in holds both channels a pass")
    func orderingRevealWaitsForTheCommit() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay(plate: true)
        var commits: [() -> Void] = []
        overlay.afterCommit = { commits.append($0) }
        overlay.revealIn(ordering: true)
        // No mask is rendered off screen per frame: the content's
        // own layer is the clip.
        #expect(overlay.content.layer?.mask == nil)
        #expect(motion(overlay.content)?.speed == 0)
        #expect(motion(overlay.stripView)?.speed == 0)
        #expect(commits.count == 1)
        commits.first?()
        let plate = try #require(motion(overlay.content))
        let items = try #require(motion(overlay.stripView))
        #expect(plate.speed == 1)
        #expect(items.speed == 1)
        #expect(plate.beginTime > 0)
        #expect(items.beginTime > plate.beginTime)
    }

    @Test("A retract starts the plate after the items")
    func retractShrinksAfterTheItems() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay(plate: true)
        #expect(overlay.retractOut())
        let plate = try #require(motion(overlay.content))
        let items = try #require(motion(overlay.stripView))
        #expect(plate.beginTime > items.beginTime)
    }

    @Test("A Boxed shelf's reveal fades the content and clips nothing")
    func boxedRevealFades() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay(plate: false)
        overlay.revealIn()
        let fade = try #require(
            motion(overlay.content) as? CABasicAnimation
        )
        #expect(fade.keyPath == "opacity")
        #expect(motion(overlay.stripView) == nil)
    }

    @Test("A reveal on a shown panel starts at once")
    func shownRevealStartsAtOnce() {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay(plate: true)
        var commits = 0
        overlay.afterCommit = { _ in commits += 1 }
        overlay.revealIn()
        #expect(motion(overlay.content)?.speed == 1)
        #expect(commits == 0)
    }

    @Test("The reveal delay ends the hover in the reveal's own pass")
    func revealEndsTheHoverInOnePass() {
        let key = ShelfManager.Key(display: DisplayID(1), edge: .top)
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
            key: ShelfRevealer.Target(
                edge: .top,
                strip: CGRect(x: 0, y: 735, width: 1000, height: 40),
                screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
                bars: [.space]
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
