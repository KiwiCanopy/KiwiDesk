import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-track floor heal (#1355): the cap makes the floors
/// fit, the heal makes the tracks draw them. The pure math first,
/// then the retile-time wiring over a real core — the
/// `TrackWeightHealTests` shape, one floor over. Display and
/// `min_window_size` pinned (#531, #660).
@Suite("Track floor heal (#1355)", .serialized)
@MainActor
struct TrackFloorHealTests {
    @Test("Equal weights re-share to draw a learned floor")
    func equalWeightsReShare() throws {
        // 980 pt across two tracks: 490/490 leaves a 600 pt floor
        // 110 pt short; the heal pins it at 600 and hands the rest
        // to the other track.
        let healed = try #require(
            TrackLayout.flooredWeights(
                weights: [1, 1],
                span: 980,
                floors: [600, 300],
                globalFloor: 300
            )
        )
        let total = healed.reduce(0, +)
        #expect(abs(980 * healed[0] / total - 600) < 0.01)
        #expect(abs(980 * healed[1] / total - 380) < 0.01)
    }

    @Test("Shares that already meet their floors are not rewritten")
    func meetingFloorsIsNil() {
        #expect(
            TrackLayout.flooredWeights(
                weights: [2, 1],
                span: 900,
                floors: [600, 300],
                globalFloor: 300
            ) == nil
        )
    }

    @Test("Floors that cannot fit leave the honest pile alone")
    func infeasibleFloorsAreNil() {
        #expect(
            TrackLayout.flooredWeights(
                weights: [1, 1],
                span: 800,
                floors: [600, 300],
                globalFloor: 300
            ) == nil
        )
    }

    @Test("Margins that cannot fit never write the boundary")
    func infeasibleMarginsAreNil() {
        // 900 holds 600 + 300 exactly and not the two margins:
        // the exact boundary is the render's pile line (#925),
        // so the count's own overlap stands instead.
        #expect(
            TrackLayout.flooredWeights(
                weights: [1, 1],
                span: 900,
                floors: [600, 300],
                globalFloor: 300,
                margin: 0.25
            ) == nil
        )
    }

    @Test("A share under min_window_size sinks without tolerance")
    func underGlobalFloorSinks() throws {
        // 299 against the 300 global floor is a pile to the
        // render, whatever the bound quantum says.
        let healed = try #require(
            TrackLayout.flooredWeights(
                weights: [299, 701],
                span: 1000,
                floors: [300, 300],
                globalFloor: 300,
                margin: 0.25
            )
        )
        let total = healed.reduce(0, +)
        #expect(abs(1000 * healed[0] / total - 300.25) < 0.01)
    }

    @Test("A second track sinking under the re-share is pinned too")
    func cascadingPins() throws {
        // 1200 pt at 1:2:2 — 240/480/480: only the first sinks
        // at the start; pinning it at 600.25 leaves 599.75 at 1:1
        // for the others, 299.875 each, which sinks the SECOND
        // under its 350 floor only now; the second round pins it
        // at 350.25 and the third takes the 249.5 left.
        let healed = try #require(
            TrackLayout.flooredWeights(
                weights: [1, 2, 2],
                span: 1200,
                floors: [600, 350, 200],
                globalFloor: 200,
                margin: 0.25
            )
        )
        let total = healed.reduce(0, +)
        let shares = healed.map { 1200 * $0 / total }
        #expect(abs(shares[0] - 600.25) < 0.01)
        #expect(abs(shares[1] - 350.25) < 0.01)
        #expect(abs(shares[2] - 249.5) < 0.01)
    }

    @Test("A pinned track takes the margin where the span affords it")
    func marginAboveTheFloor() throws {
        // The shave's quarter-point (`minSizeMargin`) keeps the
        // two passes agreeing on where a share meets its floor.
        let healed = try #require(
            TrackLayout.flooredWeights(
                weights: [1, 1],
                span: 1000,
                floors: [600, 300],
                globalFloor: 300,
                margin: 0.25
            )
        )
        let total = healed.reduce(0, +)
        #expect(abs(1000 * healed[0] / total - 600.25) < 0.01)
    }

    @Test("A share within the match tolerance is not re-shared")
    func toleranceUnderTheFloor() {
        // 599 against a 600 LEARNED floor is the same span
        // (#677's quantum, the app's own clamp): rewriting it
        // would churn every retile.
        #expect(
            TrackLayout.flooredWeights(
                weights: [599, 401],
                span: 1000,
                floors: [600, 300],
                globalFloor: 300
            ) == nil
        )
    }

    /// Two own-track windows on a pinned 1200×800 display.
    private func makeCore() -> (KiwiCore, SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-floor-heal-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(core.tiler.settings.minWindowSize == 300)
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
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return (core, space)
    }

    @Test("A retile re-shares the tracks to a learned floor")
    func retileHealsToLearnedFloor() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore()
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        // Teach a corroborated 700 pt floor on w1: two distinct
        // asks, each refused twice with the same answer (the
        // ladder itself is `SizeBoundLearnerTests`; this is the
        // wire).
        for asked in [CGFloat(500), CGFloat(450)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    w1,
                    size: CGSize(width: asked, height: 700)
                )
                core.tiler.boundLearner.observe(
                    w1,
                    currentSize: CGSize(width: 700, height: 700),
                    settledRead: true
                )
            }
        }
        #expect(core.tiler.sizeBound(for: w1)?.minWidth == 700)
        // The write is observed on the log seam: a re-share
        // round-trips its values bit-exactly, so value equality
        // cannot see a second write.
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.retile()
        #expect(log.contains { $0.contains("re-shared") })
        let healed = try #require(core.state.workspaces[space])
        let head = healed.trackWeights[w1] ?? 1
        let other = healed.trackWeights[w2] ?? 1
        #expect(head > other)
        let frame = try #require(
            core.tiler.calculatedFrames(state: core.state)[w1]
        )
        #expect(frame.width >= 700 - 0.5)
        #expect(
            core.tiler.calculatedFrames(state: core.state)[w2]!
                .width >= 300 - 0.5
        )
        // Idempotent: the next retile finds every share at its
        // floor and rewrites nothing.
        let before = healed.trackWeights
        log.removeAll()
        core.retile()
        #expect(
            core.state.workspaces[space]?.trackWeights == before
        )
        #expect(!log.contains { $0.contains("re-shared") })
    }
}
