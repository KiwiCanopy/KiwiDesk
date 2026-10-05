import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Where the #1959 hold is armed: `spaceSwitchRetile` holds the
/// arriving Space's focus anchor when the switch brings it out of
/// its park, reading the plate slide's lift live — and never for a
/// window already shown, whose ring leads as before. Display pinned
/// (#531); the hold's timer is inert in `makeTestCore`.
@Suite("Border ring arrival wiring (#1959)", .serialized)
@MainActor
struct BorderArrivalWiringTests {
    /// Window 1 in Space 1 (shown), window 2 in Space 2 (parked,
    /// its echo landed), both on the main screen.
    private func makeCore(slide: Bool = false) throws -> KiwiCore {
        let screen = try #require(NSScreen.main)
        let display = try #require(screen.kiwiDisplayID)
        let core = makeTestCore()
        // The park and the "is it parked" read share one screen,
        // as `BootRestoreFixture` pins them.
        let pinned = GeometryUtils.axVisibleFrame(of: screen)
        core.tiler.visibleBounds = { _ in pinned }
        core.tiler.allScreenBounds = { [pinned] }
        core.tiler.animation.isEnabled = false
        core.tiler.settings.animations.onSpaceChange = slide
        core.spaceSlide.reduceMotion = { !slide }
        for (id, space) in [(WindowID(1), 1), (WindowID(2), 2)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "A")
                )
            )
            core.state.workspaces.add(id, to: SpaceID(space))
            core.state.workspaces.assign(SpaceID(space), to: display)
        }
        core.state.workspaces.stampFocus(WindowID(2), in: SpaceID(2))
        core.state.workspaces.activate(SpaceID(1))
        core.retile()
        for id in [WindowID(1), WindowID(2)] {
            let frame = try #require(core.tiler.placements.recent(id))
            core.state.apply(.windowResized(id, frame))
        }
        return core
    }

    @Test("a switch holds the anchor it brings out of its park")
    func switchHoldsTheParkedAnchor() throws {
        let core = try makeCore()
        core.execute("focus_space", args: [.string("2")])
        #expect(core.borders.arrival?.window == WindowID(2))
    }

    /// A focus follow onto a Space already shown sends the window
    /// nothing, so nothing would ever arrive: its ring leads.
    @Test("an anchor already shown is not held")
    func shownAnchorIsNotHeld() throws {
        let core = try makeCore()
        let shown = try #require(core.state.windows[WindowID(2)]?.frame)
        let slot = try #require(
            core.state.windows[WindowID(1)]?.frame
        )
        core.state.apply(.windowResized(WindowID(2), slot))
        #expect(shown != slot)
        core.execute("focus_space", args: [.string("2")])
        #expect(core.borders.arrival == nil)
    }

    @Test("the hold waits for the slide's own lift")
    func holdReadsTheSlidesLift() throws {
        let core = try makeCore(slide: true)
        core.execute("focus_space", args: [.string("2")])
        let lift = try #require(core.spaceSlide.play?.liftAt)
        let hold = try #require(core.borders.arrival)
        #expect(hold.notBefore() == lift)
    }
}
