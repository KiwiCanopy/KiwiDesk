import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-track-resize-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

@MainActor
private func makeTrackSpace(
    _ core: KiwiCore,
    windows count: Int,
    focus: WindowID
) -> SpaceID {
    for id in 1...count {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)"
                )
            )
        )
    }
    let space = core.state.workspaces.space(of: WindowID(1))!
    // own_track so mode-entry seeds one window per track — the
    // multi-track fixture these tests exercise. #437 flipped the
    // default to fill-then-spill, whose seed would pack them.
    core.execute(
        "track.set_new_window",
        args: [.string("own_track")]
    )
    core.execute(
        "set_mode",
        args: [.string(space.raw), .string("track")]
    )
    core.state.workspaces.focus(focus, in: space)
    return space
}

/// Track `resize` (#128): across the axis = my track's weight,
/// along it = my share within the track. One true target each.
@Suite("Track resize (#128)", .serialized)
@MainActor
struct TrackResizeTests {
    @Test("Across-axis resize grows the focused track's weight")
    func growsTrackWeight() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 2,
            focus: WindowID(1)
        )
        #expect(
            core.execute(
                "resize",
                args: [.string("x"), .number(100)]
            ).isSuccess
        )
        let weights =
            core.state.workspaces[space]!.trackWeights
        #expect((weights[WindowID(1)] ?? 1) > 1)
        #expect(weights[WindowID(2)] == nil)
    }

    @Test("Along-axis resize grows the in-track share")
    func growsShare() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 3,
            focus: WindowID(2)
        )
        core.state.workspaces.withSpace(space) {
            // Two tracks: [1] [2, 3].
            $0.trackBreaks = [WindowID(2)]
        }
        #expect(
            core.execute(
                "resize",
                args: [.string("y"), .number(100)]
            ).isSuccess
        )
        let after = core.state.workspaces[space]!
        #expect((after.stackWeights[WindowID(2)] ?? 1) > 1)
        // Track weights untouched by the along-axis knob.
        #expect(after.trackWeights.isEmpty)
    }

    @Test("A single track cannot trade cross-axis space")
    func singleTrackFails() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 2,
            focus: WindowID(1)
        )
        core.state.workspaces.withSpace(space) {
            $0.trackBreaks = []
        }
        #expect(
            !core.execute(
                "resize",
                args: [.string("x"), .number(100)]
            ).isSuccess
        )
    }

    @Test("A window alone in its track has no share to grow")
    func aloneFails() {
        let core = makeCore()
        _ = makeTrackSpace(core, windows: 2, focus: WindowID(1))
        #expect(
            !core.execute(
                "resize",
                args: [.string("y"), .number(100)]
            ).isSuccess
        )
    }

    @Test("A horizontal axis swaps the two knobs")
    func horizontalSwapsAxes() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 2,
            focus: WindowID(1)
        )
        core.execute(
            "track.set_axis",
            args: [.string("horizontal")]
        )
        // Rows: "y" now trades TRACK space.
        #expect(
            core.execute(
                "resize",
                args: [.string("y"), .number(100)]
            ).isSuccess
        )
        let weights =
            core.state.workspaces[space]!.trackWeights
        #expect((weights[WindowID(1)] ?? 1) > 1)
    }

    @Test("Writes clamp to the shared weight range")
    func clampsToRange() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 2,
            focus: WindowID(1)
        )
        for _ in 0..<50 {
            core.execute(
                "resize",
                args: [.string("x"), .number(5000)]
            )
        }
        let weight =
            core.state.workspaces[space]!
            .trackWeights[WindowID(1)] ?? 1
        #expect(weight <= TrackLayout.weightRange.upperBound)
    }

    @Test("Shrink stops at min_window_size floor without cascade")
    func shrinkStopsAtMinSize() {
        let span: Double = 1200
        let minSize: Double = 150
        var weights = [1.0, 1.0, 1.0]
        for _ in 0..<50 {
            weights[0] = StackLayout.weightStep(
                weights: weights,
                at: 0,
                delta: -100,
                span: span,
                minSize: minSize
            )
        }
        let total = weights.reduce(0, +)
        let smallest = weights.min()!
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: smallest,
            span: span,
            minSize: minSize
        )
        #expect(total <= limit + 0.0001)
        let window0Size = span * (weights[0] / total)
        #expect(window0Size >= minSize - 0.0001)
    }

    @Test("Mouse drag across tracks updates track weight")
    func mouseDragAcross() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 2,
            focus: WindowID(1)
        )
        let slot = CGRect(x: 0, y: 25, width: 400, height: 700)
        let dragged = CGRect(x: 0, y: 25, width: 500, height: 700)
        core.handleResizeEnd(
            WindowID(1),
            slot: slot,
            frame: dragged,
            in: core.state.workspaces[space]!
        )
        let weights =
            core.state.workspaces[space]!.trackWeights
        #expect((weights[WindowID(1)] ?? 1) > 1)
    }

    @Test("Mouse drag along track updates in-track share")
    func mouseDragAlong() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 3,
            focus: WindowID(2)
        )
        core.state.workspaces.withSpace(space) {
            $0.trackBreaks = [WindowID(2)]
        }
        let slot = CGRect(x: 400, y: 25, width: 400, height: 350)
        let dragged = CGRect(x: 400, y: 25, width: 400, height: 450)
        core.handleResizeEnd(
            WindowID(2),
            slot: slot,
            frame: dragged,
            in: core.state.workspaces[space]!
        )
        let after = core.state.workspaces[space]!
        #expect((after.stackWeights[WindowID(2)] ?? 1) > 1)
    }
}
