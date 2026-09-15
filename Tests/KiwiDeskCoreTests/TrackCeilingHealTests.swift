import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-track heal's ceiling half (#1488): a track whose
/// members can draw no wider than a learned maximum hands its
/// surplus to the others instead of standing empty beside a
/// fixed-size window. The pure math first, then the retile-time
/// wiring — `TrackFloorHealTests`' shape, one bound over.
/// Display and `min_window_size` pinned (#531, #660).
@Suite("Track ceiling heal (#1488)", .serialized)
@MainActor
struct TrackCeilingHealTests {
    @Test("A fixed-size track yields its surplus to the neighbour")
    func fixedSizeYieldsSurplus() throws {
        // 1000 pt at 1:1 — 500/500 — with track 0 unable to draw
        // past 400: it lands at 400 and the neighbour takes 600.
        let healed = try #require(
            TrackLayout.flooredWeights(
                weights: [1, 1],
                span: 1000,
                floors: [400, 300],
                ceilings: [400, .infinity],
                globalFloor: 300
            )
        )
        let total = healed.reduce(0, +)
        #expect(abs(1000 * healed[0] / total - 400) < 0.01)
        #expect(abs(1000 * healed[1] / total - 600) < 0.01)
    }

    @Test("A ceiling gives room back where the others' floors need it")
    func ceilingYieldsToFloors() throws {
        // 1706 pt at 10:1:1 — 1421/142/142: track 0 overflows an
        // 825 ceiling AND the other two sink under 500 floors.
        // Pinning track 0 at 825 leaves 881 for two 500.25 floors,
        // which do not fit — so the level settles with the floors
        // met and track 0 between its bounds at 705.5.
        let healed = try #require(
            TrackLayout.flooredWeights(
                weights: [10, 1, 1],
                span: 1706,
                floors: [300, 500, 500],
                ceilings: [825, .infinity, .infinity],
                globalFloor: 300,
                margin: 0.25
            )
        )
        let total = healed.reduce(0, +)
        let shares = healed.map { 1706 * $0 / total }
        #expect(abs(shares[0] - 705.5) < 0.01)
        #expect(abs(shares[1] - 500.25) < 0.01)
        #expect(abs(shares[2] - 500.25) < 0.01)
    }

    @Test("Ceilings that together leave the span unfilled are nil")
    func unfillableCeilingsAreNil() {
        // Two fixed-size windows at 400 each cannot fill 1000:
        // the gap is honest, and the weights are left alone.
        #expect(
            TrackLayout.flooredWeights(
                weights: [1, 1],
                span: 1000,
                floors: [300, 300],
                ceilings: [400, 400],
                globalFloor: 300
            ) == nil
        )
    }

    @Test("A share within the tolerance over its ceiling is not re-shared")
    func toleranceOverTheCeiling() {
        // 401 against a 400 learned ceiling is the same span
        // (#677's quantum): rewriting it would churn every retile.
        #expect(
            TrackLayout.flooredWeights(
                weights: [401, 599],
                span: 1000,
                floors: [300, 300],
                ceilings: [400, .infinity],
                globalFloor: 300
            ) == nil
        )
    }

    @Test("A ceiling under the floor is noise and rewrites nothing")
    func ceilingUnderFloorIsNoise() {
        // The count fitted the 500 floor; a 450 ceiling beside it
        // cannot make the 500 share overflow.
        #expect(
            TrackLayout.flooredWeights(
                weights: [1, 1],
                span: 1000,
                floors: [500, 300],
                ceilings: [450, .infinity],
                globalFloor: 300,
                margin: 0.25
            ) == nil
        )
    }

    /// Two own-track windows on a pinned 1200×800 display.
    private func makeCore() -> (KiwiCore, SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-ceiling-heal-\(UUID().uuidString)"
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

    @Test("A retile hands a fixed-size window's surplus to its neighbour")
    func retileHealsToLearnedCeiling() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore()
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        // Teach a fixed 500 pt width on w1 — the System Settings
        // signature: asks on both sides answered with one span,
        // two distinct asks each (the ladder itself is
        // `SizeBoundLearnerTests`; this is the wire).
        for asked in [CGFloat(400), 450, 700, 800] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    w1,
                    size: CGSize(width: asked, height: 700)
                )
                core.tiler.boundLearner.observe(
                    w1,
                    currentSize: CGSize(width: 500, height: 700),
                    settledRead: true
                )
            }
        }
        #expect(core.tiler.sizeBound(for: w1)?.maxWidth == 500)
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.retile()
        #expect(log.contains { $0.contains("re-shared") })
        let healed = try #require(core.state.workspaces[space])
        let head = healed.trackWeights[w1] ?? 1
        let other = healed.trackWeights[w2] ?? 1
        #expect(head < other)
        let frames = core.tiler.calculatedFrames(state: core.state)
        let fixed = try #require(frames[w1])
        let neighbour = try #require(frames[w2])
        #expect(abs(fixed.width - 500) < 0.5)
        // The neighbour takes everything the fixed window cannot:
        // the two together span the usable width.
        #expect(neighbour.maxX > fixed.maxX + 500)
        // Idempotent: the next retile finds every share inside
        // its bounds and rewrites nothing.
        let before = healed.trackWeights
        log.removeAll()
        core.retile()
        #expect(
            core.state.workspaces[space]?.trackWeights == before
        )
        #expect(!log.contains { $0.contains("re-shared") })
    }
}
