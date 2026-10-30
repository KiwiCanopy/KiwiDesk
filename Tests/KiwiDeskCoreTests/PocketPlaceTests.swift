import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's one place ladder (#2793): the drawing and the landing
/// read `pocketPlace`, so a put-in lands where the pocket is drawn on
/// every arm; and the One-window pocket's leave keeps its panel until
/// its landing, which a return in the meantime takes back.
@Suite(
    "Pocket place and leave (#2793)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketPlaceTests {
    private let one = WindowID(1)

    private func makeCore(
        bar: AppBarEdge = .bottom,
        pocket: AppBarEdge = .bottom
    ) throws -> (KiwiCore, Display) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-place-\(UUID().uuidString)")
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: one,
                    pid: 900_001,
                    appName: "App1",
                    title: "Window 1",
                    frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                )
            )
        )
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        let display = Display(id: id, name: "Main", frame: screen.frame)
        core.state.workspaces.upsertDisplay(display)
        core.state.workspaces.assign(space, to: id)
        // Pinned (tests.md, #531).
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        core.tiler.settings.spaceBarStyle.setEdge(bar)
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.kiwishelf.pocketEdge = pocket
        // A margin, so a landing that drops it differs from the drawing.
        core.tiler.settings.kiwishelf.outerMargin = 8
        return (core, display)
    }

    /// The landing the drawn spec promises: its frame back in AX, less
    /// the margin the mark stands in from.
    private func drawnLanding(_ core: KiwiCore, _ id: DisplayID) -> CGRect? {
        guard let spec = core.pocketPlate.specs[id] else { return nil }
        let frame = GeometryUtils.flip(
            spec.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        guard let edge = spec.handle else { return frame }
        return PocketPlateView.room(in: frame, edge: edge, outer: spec.outer)
    }

    @Test("a put-in lands where the pocket is drawn, on every arm")
    func landingIsTheDrawing() throws {
        // Under One window: inside a bar's strip, and whole on an edge
        // no bar shows.
        for pocket in [AppBarEdge.bottom, .left] {
            let (core, display) = try makeCore(pocket: pocket)
            core.pocketPlate.dragging = one
            core.updateBars()
            let place = core.pocketPlace(on: display.id)
            if pocket == .bottom {
                let inside = try #require(
                    core.pocketInsideFrame(on: display.id)
                )
                #expect(place == .inside(inside))
            } else {
                #expect(place == .whole(slides: true))
            }
            #expect(core.pocketPlate.specs[display.id]?.slides == true)
            let landing = core.pocketLanding(on: display.id)
            #expect(landing != nil)
            #expect(landing == drawnLanding(core, display.id))
        }
        // Under Several: the shelf's section.
        let (core, display) = try makeCore()
        core.execute("pocket.set_capacity", args: [.string("several")])
        core.updateBars()
        guard case .section(let slot) = core.pocketPlace(on: display.id)
        else {
            Issue.record("no section under Several")
            return
        }
        #expect(core.pocketLanding(on: display.id) == slot)
        #expect(core.pocketPlate.specs[display.id]?.slides == false)
        // Under Several on an edge no bar shows, the bars Always: the
        // whole mark at rest, which never slides (#2784 ▸ 8).
        let (rest, shown) = try makeCore(pocket: .left)
        rest.execute("pocket.set_capacity", args: [.string("several")])
        rest.updateBars()
        #expect(rest.pocketPlace(on: shown.id) == .whole(slides: false))
        #expect(rest.pocketPlate.specs[shown.id]?.slides == false)
        let landing = rest.pocketLanding(on: shown.id)
        #expect(landing != nil)
        #expect(landing == drawnLanding(rest, shown.id))
    }

    @Test("a leave holds the panel until its landing; a return keeps it")
    func leaveLandsOrReturns() throws {
        let (core, display) = try makeCore()
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        var landings: [@MainActor () -> Void] = []
        core.pocketPlate.isOnScreen = { _ in true }
        core.pocketPlate.afterLeave = { _, body in landings.append(body) }
        core.pocketPlate.dragging = one
        core.updateBars()
        core.endPocketDrag()
        // The leave plays and waits for its landing.
        #expect(core.pocketPlate.leaving[display.id] != nil)
        #expect(landings.count == 1)
        // Back before it lands: the return stands it at once, with no
        // second entrance.
        core.pocketPlate.dragging = one
        core.updateBars()
        #expect(core.pocketPlate.leaving[display.id] == nil)
        let view = try #require(core.pocketPlate.view(on: display.id))
        #expect(view.layer?.animation(forKey: "pocketEntrance") == nil)
        // Gone again: the first, stale landing leaves the new leave
        // standing, and only its own landing ends it.
        core.endPocketDrag()
        let token = core.pocketPlate.leaving[display.id]
        #expect(token != nil)
        landings.removeFirst()()
        #expect(core.pocketPlate.leaving[display.id] == token)
        landings.removeFirst()()
        #expect(core.pocketPlate.leaving[display.id] == nil)
    }
}
