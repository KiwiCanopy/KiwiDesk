import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// How a hiding shelf's reveal and its mark's hover MOVE (#761):
/// the grow clips the content's own layer and starts only after
/// the pass that orders the panel in, and the hovered plate grows
/// its frame rather than cross-fading a redraw. Whether it reads
/// smoothly is the device's; this holds the shapes that made it
/// stutter. Main-actor spend: a handful of unwindowed views.
@Suite("Shelf reveal motion (#761)")
@MainActor
struct ShelfRevealMotionTests {
    private static let mark = CGRect(x: 100, y: 0, width: 60, height: 8)

    @Test("The hovered plate grows on every side, never under Reduce Motion")
    func hoverPlateGrows() {
        let grown = BarMotion.hoverPlate(
            mark: Self.mark,
            hovered: true,
            reduceMotion: false
        )
        let growth = ShelfIndicatorSpec.hoverGrowth
        #expect(grown == Self.mark.insetBy(dx: -growth, dy: -growth))
        #expect(
            BarMotion.hoverPlate(
                mark: Self.mark,
                hovered: true,
                reduceMotion: true
            ) == Self.mark
        )
        #expect(
            BarMotion.hoverPlate(
                mark: Self.mark,
                hovered: false,
                reduceMotion: false
            ) == Self.mark
        )
    }

    @Test("A grow starts at the hovered plate the hover leaves")
    func growStartsAtTheHoveredPlate() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 40)
        let motion = BarMotion.revealMotion(
            reduceMotion: false,
            origin: Self.mark,
            bounds: bounds
        )
        let plate = BarMotion.hoverPlate(
            mark: Self.mark,
            hovered: true,
            reduceMotion: false
        )
        guard case .grow(let from, let to, let radius, _) = motion else {
            Issue.record("no grow: \(motion)")
            return
        }
        #expect(from == plate)
        #expect(to == bounds)
        #expect(radius == plate.height / 2)
    }

    private func spec(hovered: Bool, shown: Bool = false)
        -> ShelfIndicatorSpec
    {
        ShelfIndicatorSpec(
            mark: .dots([.init(current: true, occupied: true)]),
            frame: Self.mark,
            horizontal: true,
            fill: "#000000",
            currentInk: "#FFFFFF",
            ink: "#AAAAAA",
            emptyInk: "#555555",
            highlight: "#FF0000",
            shown: shown,
            hovered: hovered
        )
    }

    /// The indicator view sized as `ShelfIndicator.show` sizes it.
    private func view() -> ShelfIndicatorView {
        let room = ShelfIndicatorSpec.hoverGrowth
        let view = ShelfIndicatorView()
        view.frame = CGRect(
            origin: .zero,
            size: Self.mark.insetBy(dx: -room, dy: -room).size
        )
        return view
    }

    @Test("A hover grows the plate's frame and leaves the dots alone")
    func hoverGrowsThePlate() {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let view = view()
        view.render(spec(hovered: false), animated: false)
        let room = ShelfIndicatorSpec.hoverGrowth
        let resting = view.bounds.insetBy(dx: room, dy: room)
        #expect(view.plate.frame == resting)
        #expect(view.dots.frame == resting)
        view.render(spec(hovered: true), animated: false)
        #expect(view.plate.frame == view.bounds)
        #expect(view.dots.frame == resting)
        #expect(
            view.plate.layer?.borderWidth == ShelfIndicatorSpec.hoverBorder
        )
    }

    @Test("Under Reduce Motion a hover takes the rim alone")
    func reducedHoverIsTheRim() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let view = view()
        view.render(spec(hovered: true), animated: true)
        let room = ShelfIndicatorSpec.hoverGrowth
        #expect(view.plate.frame == view.bounds.insetBy(dx: room, dy: room))
        #expect(
            view.plate.layer?.borderWidth == ShelfIndicatorSpec.hoverBorder
        )
    }

    @Test("A reveal ordering the panel in holds its start for one pass")
    func orderingRevealWaitsForTheCommit() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = ShelfOverlay()
        var commits: [() -> Void] = []
        overlay.afterCommit = { commits.append($0) }
        overlay.afterReveal = { _, _ in }
        overlay.content.frame = CGRect(x: 0, y: 0, width: 400, height: 40)
        overlay.revealIn(ordering: true)
        let layer = try #require(overlay.content.layer)
        // No mask is rendered off screen per frame: the content's
        // own layer is the clip.
        #expect(layer.mask == nil)
        let held = try #require(layer.animation(forKey: "kiwi.reveal"))
        #expect(held.speed == 0)
        #expect(commits.count == 1)
        commits.first?()
        let running = try #require(layer.animation(forKey: "kiwi.reveal"))
        #expect(running.speed == 1)
        #expect(running.beginTime > 0)
    }

    @Test("A reveal on a shown panel starts at once")
    func shownRevealStartsAtOnce() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = ShelfOverlay()
        var commits = 0
        overlay.afterCommit = { _ in commits += 1 }
        overlay.afterReveal = { _, _ in }
        overlay.content.frame = CGRect(x: 0, y: 0, width: 400, height: 40)
        overlay.revealIn()
        let layer = try #require(overlay.content.layer)
        let running = try #require(layer.animation(forKey: "kiwi.reveal"))
        #expect(running.speed == 1)
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
