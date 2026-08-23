import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The retile-time session-weight heal, end to end (#944): a
/// stored weight written under an OLD membership must be shaved
/// at the next retile once a membership change makes it pile
/// the space — and a legal weight must never be touched. The
/// pure math is `WeightHealTests`; this suite pins that
/// `KiwiCore.retile` actually consults it, over real state,
/// with the same span/keying derivations the resize paths use.
@Suite("Track weight heal (#944)", .serialized)
@MainActor
struct TrackWeightHealTests {

    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-weight-heal-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        // Pinned display (#531) and the default the arithmetic
        // below reasons from (#660).
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(core.tiler.settings.minWindowSize == 300)
        return core
    }

    /// One window per track (`own_track` seed), focus on 1.
    private func makeTrackSpace(
        _ core: KiwiCore,
        windows count: Int
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
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return space
    }

    /// The layouts' raw cascade limit for the space's current
    /// track weights — recomputed from the same authorities the
    /// heal uses, so the assertion cannot drift from the code.
    private func trackFeasibility(
        _ core: KiwiCore,
        space id: SpaceID
    ) -> (total: Double, limit: Double) {
        let space = core.state.workspaces[id]!
        let tiled = core.state.effectiveTiledMembers(
            of: space,
            activeSpace: id
        )
        let params = core.tiler.settings.resolvedTrack(for: id)
        let ranges = TrackLayout.ranges(
            of: TrackLayout.counts(
                of: tiled,
                breaks: space.trackBreaks,
                cap: params.trackCap
            )
        )
        let weights = ranges.map {
            TrackLayout.weight(
                ofTrack: $0,
                tiled: tiled,
                weights: space.trackWeights
            )
        }
        let gaps = core.tiler.settings.gaps(for: id)
        let span = StackLayout.weightedSpan(
            region: 1200,
            outer: Double(
                gaps.outer.left + gaps.outer.right
            ),
            innerGap: Double(gaps.inner.horizontal),
            count: ranges.count
        )
        return (
            weights.reduce(0, +),
            StackLayout.maxColumnTotal(
                smallestWeight: weights.min() ?? 1,
                span: span,
                minSize: Double(
                    core.tiler.settings.minWindowSize
                )
            )
        )
    }

    @Test("a stale extreme track weight is healed at retile")
    func staleExtremeWeightHeals() {
        let core = makeCore()
        // Three tracks holding a stored 10.0 — the #944 state: a
        // weight legal under an OLD membership after a third
        // track arrived. Built directly (the heal is
        // history-agnostic; how the state got here is the spawn
        // paths' own suites' business), because the write-time
        // clamps would refuse authoring it against THIS
        // membership — which is the point.
        let space = makeTrackSpace(core, windows: 3)
        core.state.workspaces.withSpace(space) {
            $0.trackWeights[WindowID(1)] = 10
        }
        core.retile()
        let after = trackFeasibility(core, space: space)
        #expect(after.total <= after.limit)
        // The stored extreme itself was shaved, not merely
        // out-averaged.
        let weights =
            core.state.workspaces[space]!.trackWeights
        #expect(weights[WindowID(1)] != nil)
        #expect((weights[WindowID(1)] ?? 1) < 10)
        // And the render tiles: three distinct column origins,
        // not one pile.
        let input = core.tiler.layoutInput(state: core.state)!
        let frames = TrackLayout().calculateGeometry(
            for: input.tiled,
            in: input.context
        )
        let origins = Set(frames.values.map(\.minX))
        #expect(origins.count == 3)
    }

    @Test("a feasible weight is never rewritten")
    func feasibleWeightIsUntouched() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 2)
        core.state.workspaces.withSpace(space) {
            $0.trackWeights[WindowID(1)] = 2
        }
        core.retile()
        #expect(
            core.state.workspaces[space]!
                .trackWeights[WindowID(1)] == 2
        )
    }

    @Test("a stale extreme in-track share is healed at retile")
    func staleColumnShareHeals() {
        let core = makeCore()
        // Taller than wide so one column legally holds three
        // 300 pt members along its axis.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 800, height: 1200)
        }
        let space = makeTrackSpace(core, windows: 3)
        // Merge into ONE three-member column carrying an extreme
        // stored share — the post-membership-change state, built
        // directly for the same reason as the track test above.
        core.state.workspaces.withSpace(space) {
            $0.trackBreaks.removeAll()
            $0.stackWeights[WindowID(1)] = 10
        }
        core.retile()
        let shares =
            core.state.workspaces[space]!.stackWeights
        #expect((shares[WindowID(1)] ?? 1) < 10)
        // The healed column tiles: three distinct y origins in
        // the single track.
        let input = core.tiler.layoutInput(state: core.state)!
        let frames = TrackLayout().calculateGeometry(
            for: input.tiled,
            in: input.context
        )
        let origins = Set(frames.values.map(\.minY))
        #expect(origins.count == 3)
    }
}
