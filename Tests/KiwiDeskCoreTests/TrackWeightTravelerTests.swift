import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The heal's LOCAL-membership ruling (#944): a visiting
/// tiled-sticky traveler must never tip the heal into
/// permanently shaving stored weights — split from
/// `TrackWeightHealTests` at the §2.1 ceiling. Per-file private
/// fixture copies, per tests.md's convention.
@Suite("Track weight heal traveler scope (#944)", .serialized)
@MainActor
struct TrackWeightTravelerTests {

    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-weight-traveler-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        // TALL on purpose: the 3-member shave branch must be
        // REACHABLE (see the reachability pin below) — on a
        // shorter display an infeasible 3-member column lands
        // in `healedWeights`' honest-physics nil and the test
        // passes with the ruling reverted (review round 3).
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 800, height: 1400)
        }
        #expect(core.tiler.settings.minWindowSize == 300)
        return core
    }

    @Test("a visiting traveler never tips the heal")
    func travelerVisitDoesNotShave() {
        let core = makeCore()
        // One two-member column whose stored share is feasible
        // for the LOCAL membership but would be infeasible with
        // a third member counted.
        for id in 1...2 {
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
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        core.state.workspaces.withSpace(space) {
            $0.trackBreaks.removeAll()
            $0.stackWeights[WindowID(1)] = 3.0
        }
        // A tiled-sticky window homed on ANOTHER space: the
        // active space's effective members inject it (#414 v2),
        // the local members do not — the divergence the ruling
        // is about, so pin that the injection really happens or
        // this test discriminates nothing.
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(9),
                pid: 9,
                appName: "Visitor",
                stickyScope: .global
            )
        )
        core.state.workspaces.add(WindowID(9), to: SpaceID("2"))
        let s1 = core.state.workspaces[space]!
        #expect(
            core.state.effectiveTiledMembers(
                of: s1,
                activeSpace: space
            ).contains(WindowID(9))
        )
        #expect(
            !core.state.localTiledMembers(of: s1)
                .contains(WindowID(9))
        )
        // Divergence preconditions: feasible at 2 members,
        // infeasible at 3, AND the 3-member shave branch
        // reachable (target ≥ count × smallest) — without the
        // third pin an infeasible 3-member column can land in
        // the honest-physics nil and the test passes with the
        // ruling reverted (review round 3). Computed from the
        // same span authority the heal divides.
        let screen = TilingEngine.screen(
            for: space,
            in: core.state
        )!
        let bounds = core.tiler.layoutBounds(on: screen)
        let gaps = core.tiler.settings.gaps(for: space)
        func limit(_ count: Int) -> Double {
            StackLayout.maxColumnTotal(
                smallestWeight: 1,
                span: TrackLayout.alongSpan(
                    region: Double(bounds.height),
                    gaps: gaps,
                    vertical: true,
                    count: count
                ),
                minSize: 300
            )
        }
        #expect(4.0 <= limit(2))
        #expect(5.0 > limit(3))
        #expect(
            TrackLayout.alongSpan(
                region: Double(bounds.height),
                gaps: gaps,
                vertical: true,
                count: 3
            ) >= 3 * (300 + StackLayout.minSizeMargin)
        )
        core.retile()
        // The heal read the LOCAL membership: the visitor's
        // presence must not permanently shave the stored share
        // (a transient pile during the visit is the accepted
        // cost — the ruling is the heal's doc's and
        // design-decisions').
        #expect(
            core.state.workspaces[space]!
                .stackWeights[WindowID(1)] == 3.0
        )
    }
}
