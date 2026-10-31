import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's handle answers an approaching pointer as the bars'
/// handles do (#2807): the kiwis peek on the hover, and the pocket
/// rises only after the bars' reveal delay, or at once on a push.
@Suite(
    "Pocket handle dwell",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketHandleDwellTests {
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-dwell-\(UUID().uuidString)")
        )
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.execute("pocket.set_capacity", args: [.string("several")])
        return core
    }

    private func spec(_ core: KiwiCore) -> PocketPlateOverlay.Spec? {
        core.updatePocketPlate(slots: [:])
        return core.pocketPlate.specs.values.first
    }

    private func depth(_ spec: PocketPlateOverlay.Spec) -> CGFloat {
        spec.handle?.isHorizontal == false
            ? spec.frame.width : spec.frame.height
    }

    @Test("a hover peeks the kiwis, and the pocket rises after the dwell")
    func hoverPeeksThenRises() async throws {
        let core = try makeCore()
        let rest = try #require(spec(core))
        core.pocketHovered(rest.display, true)
        let peeked = try #require(core.pocketPlate.specs[rest.display])
        #expect(peeked.peeking)
        #expect(!peeked.risen)
        // The handle's panel makes room for the peek.
        #expect(depth(peeked) == depth(rest) + PocketHandleView.peekDepth)
        let dwell = core.deferred.task(for: .pocketDwell)
        #expect(dwell != nil)
        await dwell?.value
        let risen = try #require(core.pocketPlate.specs[rest.display])
        #expect(risen.risen)
        #expect(!risen.peeking)
        core.pocketHovered(rest.display, false)
        let sunk = try #require(core.pocketPlate.specs[rest.display])
        #expect(!sunk.risen)
        #expect(!sunk.peeking)
        #expect(depth(sunk) == depth(rest))
    }

    @Test("leaving before the dwell raises nothing")
    func leavingCancels() async throws {
        let core = try makeCore()
        let rest = try #require(spec(core))
        core.pocketHovered(rest.display, true)
        let dwell = core.deferred.task(for: .pocketDwell)
        #expect(dwell != nil)
        core.pocketHovered(rest.display, false)
        await dwell?.value
        #expect(core.pocketPlate.dwelled.isEmpty)
        #expect(core.pocketPlate.specs[rest.display]?.risen == false)
    }

    @Test("a push rises at once, and one off the handle does nothing")
    func pushRisesAtOnce() throws {
        let core = try makeCore()
        let rest = try #require(spec(core))
        core.pocketPushed(rest.display)
        #expect(core.pocketPlate.specs[rest.display]?.risen == false)
        core.pocketHovered(rest.display, true)
        core.pocketPushed(rest.display)
        #expect(core.pocketPlate.specs[rest.display]?.risen == true)
    }

    @Test("a dwell ends with its hover, an order-out's included")
    func dwellEndsWithTheHover() async throws {
        let core = try makeCore()
        let rest = try #require(spec(core))
        core.pocketHovered(rest.display, true)
        await core.deferred.task(for: .pocketDwell)?.value
        #expect(core.pocketPlate.dwelled == [rest.display])
        // An ordered-out handle hears no exit; its hover goes alone.
        core.pocketPlate.hovered.remove(rest.display)
        #expect(core.pocketPlate.dwelled.isEmpty)
        core.updatePocketPlate(slots: [:])
        #expect(core.pocketPlate.specs[rest.display]?.risen == false)
    }

    @Test("a section's hover arms no dwell")
    func sectionArmsNoDwell() throws {
        let core = try makeCore()
        let display = try #require(spec(core)?.display)
        let slot = CGRect(x: 1000, y: 860, width: 40, height: 40)
        core.updatePocketPlate(slots: [display: slot])
        core.deferred.cancel(.pocketDwell)
        core.pocketHovered(display, true)
        #expect(!core.deferred.isScheduled(.pocketDwell))
    }

    @Test("the handle's view reports its hover and push to the core")
    func viewIsWired() throws {
        let core = try makeCore()
        let rest = try #require(spec(core))
        let view = try #require(core.pocketPlate.view(on: rest.display))
        view.updateTrackingAreas()
        // A push is heard on a move, not only on the way in.
        #expect(
            view.trackingAreas.contains { $0.options.contains(.mouseMoved) }
        )
        view.setHovered(true)
        #expect(core.pocketPlate.specs[rest.display]?.peeking == true)
        view.onPush()
        #expect(core.pocketPlate.specs[rest.display]?.risen == true)
    }

    @Test("a peek taken back keeps its room until the kiwis are in")
    func unpeekHoldsTheRoom() throws {
        // Under Reduce Motion nothing peeks, so nothing is held.
        guard !BarMotion.isReduced else { return }
        let core = try makeCore()
        let rest = try #require(spec(core))
        core.pocketHovered(rest.display, true)
        let panel = try #require(
            core.pocketPlate.panelForTesting(on: rest.display)
        )
        let peeked = panel.frame
        core.pocketHovered(rest.display, false)
        #expect(panel.frame == peeked)
        #expect(panel.frame != core.pocketPlate.specs[rest.display]?.frame)
    }

    @Test("the peek is the stated depth, and none under Reduce Motion")
    func peekDecision() {
        #expect(
            BarMotion.pocketPeek(peeking: true, reduceMotion: false)
                == PocketHandleView.peekDepth
        )
        #expect(BarMotion.pocketPeek(peeking: true, reduceMotion: true) == 0)
        #expect(BarMotion.pocketPeek(peeking: false, reduceMotion: false) == 0)
        // A rise out of peeking kiwis starts where they stood.
        #expect(
            BarMotion.pocketRiseTravel(peek: PocketHandleView.peekDepth)
                == BarMotion.pocketRiseTravel() - PocketHandleView.peekDepth
        )
    }
}
