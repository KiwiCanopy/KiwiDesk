import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A weight press beside a refusal (#2774): a member of a run that
/// hides nothing takes the run's step, and a press in a zone that
/// fits stops at the refusal the run would plan. `.enabled(if:)`
/// because the press resolves the Space's screen.
@Suite(
    "Run press floors (#2774)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunPressFloorTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-press-\(UUID().uuidString)"
                )
        )
        // Pinned (tests.md, #531): the zone's span is what the
        // suite reads.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        return core
    }

    /// Master w1, a stack zone of w2 and w3, focus on w2 — or, for
    /// `track`, two tracks.
    private func makeSpace(
        _ core: KiwiCore,
        mode: String = "stack"
    ) -> SpaceID {
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        if mode == "track" {
            _ = core.execute("track.set_limit", args: [.number(2)])
        }
        _ = core.execute("set_min_window_size", args: [.number(200)])
        core.state.workspaces.focus(WindowID(2), in: space)
        core.retile(animated: false)
        return space
    }

    /// The pair's drawn span along the zone, read off the layout.
    private func zoneSpan(_ core: KiwiCore) throws -> CGFloat {
        let frames = core.tiler.calculatedFrames(state: core.state)
        let two = try #require(frames[WindowID(2)])
        let three = try #require(frames[WindowID(3)])
        return two.height + three.height
    }

    private func refuse(
        _ core: KiwiCore,
        window: WindowID = WindowID(3),
        at answer: CGFloat
    ) {
        core.tiler.boundLearner.bounds[window] = .init(height: [
            .init(asked: 50, answered: answer)
        ])
        core.retile(animated: false)
    }

    /// The stack zone holding `member`, from the layout's own input.
    private func zone(
        of member: WindowID,
        in core: KiwiCore,
        space id: SpaceID
    ) throws -> (zone: RunZone, context: LayoutContext) {
        let space = try #require(core.state.workspaces[id])
        let screen = try #require(
            TilingEngine.screen(for: id, in: core.state)
        )
        let context = core.tiler.layoutInput(
            state: core.state,
            space: space,
            screen: screen
        ).context
        let tiled = core.state.effectiveTiledMembers(of: space)
        let zone = try #require(
            RunZone.zones(mode: space.mode, tiled: tiled, in: context)?
                .first { $0.members.contains(member) }
        )
        return (zone, context)
    }

    @Test("A press in a run that hides nothing takes the run step")
    func unhidingRunTakesTheRunStep() throws {
        let core = makeCore()
        let id = makeSpace(core)
        let span = try zoneSpan(core)
        // Floors fit (200 + answer), the shares do not.
        refuse(core, at: span - 200 - 10)
        #expect(
            core.tiler.runCovers[id]?.runs.contains {
                $0.shown.contains(WindowID(2))
            } != true
        )
        let space = try #require(core.state.workspaces[id])
        let (zone, context) = try zone(of: WindowID(2), in: core, space: id)
        let run = try #require(zone.run(in: context))
        let extra = zone.runExtra(in: context) ?? 0
        #expect(extra > 0)
        #expect(run.visible.count == 2)
        let expected = StackLayout.weightStep(
            weights: [1, 1],
            at: 0,
            delta: 5,
            span: Double(extra),
            minSizes: [0, 0]
        ).value
        let response = core.resizeStackMember(
            WindowID(2),
            axis: "y",
            delta: 5,
            span: 780,
            space: space
        )
        #expect(response.isSuccess)
        let weight = try #require(
            core.state.workspaces[id]?.stackWeights[WindowID(2)]
        )
        #expect(abs(weight - expected) < 0.0001)
    }

    /// The press stops where the run would start: after it the
    /// zone still fits whole, every member at its share.
    @Test("A shrink in a fitting zone stops at the refusal")
    func shrinkStopsAtTheRefusal() throws {
        let core = makeCore()
        let id = makeSpace(core)
        let span = try zoneSpan(core)
        // w3 refused once at a span below its share: the zone fits.
        refuse(core, at: span / 2 - 30)
        let before = try zone(of: WindowID(3), in: core, space: id)
        #expect(before.zone.run(in: before.context) == nil)
        let space = try #require(core.state.workspaces[id])
        core.state.workspaces.focus(WindowID(3), in: id)
        _ = core.resizeStackMember(
            WindowID(3),
            axis: "y",
            delta: -120,
            span: core.layoutSpan(of: space, horizontal: false),
            space: space
        )
        core.retile(animated: false)
        let after = try zone(of: WindowID(3), in: core, space: id)
        #expect(after.zone.run(in: after.context) == nil)
    }

    /// Track's along-axis press shares the run's clamp (#2774):
    /// two tracks, w1 and w2 sharing the first.
    @Test("A Track shrink in a fitting zone stops at the refusal")
    func trackShrinkStopsAtTheRefusal() throws {
        let core = makeCore()
        let id = makeSpace(core, mode: "track")
        let before = try zone(of: WindowID(2), in: core, space: id)
        try #require(before.zone.members == [WindowID(1), WindowID(2)])
        #expect(before.zone.vertical)
        let frames = core.tiler.calculatedFrames(state: core.state)
        let share = try #require(frames[WindowID(2)]).height
        refuse(core, window: WindowID(2), at: share - 30)
        let fitting = try zone(of: WindowID(2), in: core, space: id)
        #expect(fitting.zone.run(in: fitting.context) == nil)
        let space = try #require(core.state.workspaces[id])
        core.state.workspaces.focus(WindowID(2), in: id)
        _ = core.resizeTrackMember(
            WindowID(2),
            axis: "y",
            delta: -120,
            span: core.layoutSpan(of: space, horizontal: false),
            space: space
        )
        core.retile(animated: false)
        let after = try zone(of: WindowID(2), in: core, space: id)
        #expect(after.zone.run(in: after.context) == nil)
    }

    /// A press that stops at a refusal names the app's floor, never
    /// the setting's (#1261).
    @Test("A refusal reads as the app's minimum")
    func refusalIsAppBound() {
        let core = makeCore()
        _ = makeSpace(core)
        #expect(!core.minimumIsAppBound(of: WindowID(3), axis: "y"))
        refuse(core, at: 500)
        #expect(core.minimumIsAppBound(of: WindowID(3), axis: "y"))
    }
}
