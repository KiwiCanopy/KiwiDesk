import Foundation
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The pocket's rise read off its approach's countdown (#3368 ruling
/// 3): a delay, then a scrub to the dwell's end; the fast pace on the
/// tab from where it stands; no scrub under Reduce Motion (ruling 4).
@Suite("Pocket rise timeline (#3368)")
@MainActor
struct PocketRiseTimelineTests {
    /// The pocket's rise travel.
    static var travel: CGFloat {
        BarMotion.pocketRiseTravel(
            tabDepth: PocketHandleView.tabDepth(of: KiwiShelf())
        )
    }

    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func fill(_ length: TimeInterval) -> ShelfHandleSpec.Fill {
        .init(origin: 0.5, started: t0, until: t0.addingTimeInterval(length))
    }

    @Test("the countdown waits the reveal delay, then rises")
    func waitsThenRises() {
        let entry = fill(ShelfReveal.dwellDelay)
        #expect(
            abs(PocketRiseTimeline.delay(of: entry) - ShelfReveal.revealDelay)
                < 1e-6
        )
        #expect(PocketRiseTimeline.progress(of: entry, at: t0) == 0)
        let mid = t0.addingTimeInterval(ShelfReveal.revealDelay + 0.125)
        #expect(
            abs(PocketRiseTimeline.progress(of: entry, at: mid) - 0.5) < 1e-6
        )
        #expect(PocketRiseTimeline.progress(of: entry, at: entry.until) == 1)
        // On the tab it rises at once.
        #expect(
            PocketRiseTimeline.delay(of: fill(ShelfReveal.revealDelay)) == 0
        )
    }

    @Test("a hurry keeps the progress and takes the fast pace")
    func hurryKeepsProgress() {
        let entry = fill(ShelfReveal.dwellDelay)
        // Still in the delay: a whole fast rise.
        let early = t0.addingTimeInterval(0.05)
        let whole = PocketRiseTimeline.hurried(entry, at: early)
        #expect(whole.started == early)
        #expect(abs(whole.length - PocketRiseTimeline.fastSpan) < 1e-6)
        // Halfway up: half a fast rise, no restart.
        let mid = t0.addingTimeInterval(ShelfReveal.revealDelay + 0.125)
        let half = PocketRiseTimeline.hurried(entry, at: mid)
        #expect(abs(half.length - PocketRiseTimeline.fastSpan / 2) < 1e-6)
        #expect(half.origin == entry.origin)
    }

    @Test("the scrub holds through the delay, then runs to the end")
    func scrubShape() throws {
        let entry = fill(ShelfReveal.dwellDelay)
        let scrub = try #require(
            BarMotion.pocketScrub(
                edge: .bottom,
                side: 40,
                travel: Self.travel,
                rise: entry,
                pace: PocketRiseTimeline.span,
                from: nil,
                reduceMotion: false
            )
        )
        #expect(abs(scrub.beginTime - ShelfReveal.revealDelay) < 1e-6)
        #expect(abs(scrub.duration - PocketRiseTimeline.span) < 1e-6)
        #expect(scrub.fillMode == .both)
        #expect(!scrub.isRemovedOnCompletion)
        // Taken over a quarter up, it runs the rest at once.
        let taken = try #require(
            BarMotion.pocketScrub(
                edge: .bottom,
                side: 40,
                travel: Self.travel,
                rise: entry,
                pace: PocketRiseTimeline.span,
                from: Self.drawn(0.25, edge: .bottom),
                reduceMotion: false
            )
        )
        #expect(taken.beginTime == 0)
        #expect(abs(taken.duration - 0.75 * PocketRiseTimeline.span) < 1e-6)
        // Already up: nothing left to run.
        #expect(
            BarMotion.pocketScrub(
                edge: .bottom,
                side: 40,
                travel: Self.travel,
                rise: entry,
                pace: PocketRiseTimeline.span,
                from: CATransform3DIdentity,
                reduceMotion: false
            ) == nil
        )
    }

    /// A pocket drawn `done` of the way up on `edge`, side 40.
    static func drawn(_ done: CGFloat, edge: AppBarEdge) -> CATransform3D {
        let start = BarMotion.pocketRiseStart(
            edge: edge,
            side: 40,
            travel: Self.travel
        )
        var shown = CATransform3DIdentity
        shown.m41 = start.m41 * (1 - done)
        shown.m42 = start.m42 * (1 - done)
        return shown
    }

    @Test("progress reads the drawn rise on every edge")
    func progressPerEdge() {
        for edge in AppBarEdge.allCases {
            let start = BarMotion.pocketRiseStart(
                edge: edge,
                side: 40,
                travel: Self.travel
            )
            #expect(
                PocketRiseTimeline.progress(shown: start, start: start) == 0
            )
            #expect(
                PocketRiseTimeline.progress(
                    shown: CATransform3DIdentity,
                    start: start
                ) == 1
            )
            let mid = PocketRiseTimeline.progress(
                shown: Self.drawn(0.4, edge: edge),
                start: start
            )
            #expect(abs(mid - 0.4) < 1e-6, Comment(rawValue: "\(edge)"))
            // Read off the axis the rise travels: the other axis held
            // at its start says nothing.
            var travel = start
            let along = abs(start.m41) > abs(start.m42)
            if along { travel.m41 *= 0.6 } else { travel.m42 *= 0.6 }
            let read = PocketRiseTimeline.progress(shown: travel, start: start)
            #expect(abs(read - 0.4) < 1e-6, Comment(rawValue: "\(edge)"))
        }
    }

    @Test("a hurry runs the distance left at the fast pace")
    func hurrySpeed() throws {
        let hurry = PocketRiseTimeline.hurried(
            fill(ShelfReveal.dwellDelay),
            at: t0.addingTimeInterval(0.2)
        )
        #expect(
            PocketRiseTimeline.pace(onTab: true) == PocketRiseTimeline.fastSpan
        )
        #expect(
            PocketRiseTimeline.pace(onTab: false) == PocketRiseTimeline.span
        )
        let scrub = try #require(
            BarMotion.pocketScrub(
                edge: .left,
                side: 40,
                travel: Self.travel,
                rise: hurry,
                pace: PocketRiseTimeline.fastSpan,
                from: Self.drawn(0.6, edge: .left),
                reduceMotion: false
            )
        )
        #expect(scrub.beginTime == 0)
        #expect(abs(scrub.duration - 0.4 * PocketRiseTimeline.fastSpan) < 1e-6)
    }

    @Test("Reduce Motion scrubs and sinks nothing")
    func reducedHoldsStill() {
        #expect(
            BarMotion.pocketScrub(
                edge: .bottom,
                side: 40,
                travel: Self.travel,
                rise: fill(ShelfReveal.dwellDelay),
                pace: PocketRiseTimeline.span,
                from: nil,
                reduceMotion: true
            ) == nil
        )
        #expect(
            BarMotion.pocketSink(
                edge: .bottom,
                side: 40,
                travel: Self.travel,
                from: CATransform3DIdentity,
                reduceMotion: true
            ) == nil
        )
    }

    @Test("a sink runs back to the handle's kiwis and holds there")
    func sinkShape() throws {
        let sink = try #require(
            BarMotion.pocketSink(
                edge: .left,
                side: 40,
                travel: Self.travel,
                from: CATransform3DIdentity,
                reduceMotion: false
            )
        )
        #expect(sink.duration == BarMotion.pocketSinkSpan)
        // From part way up, the distance up times the pace.
        let part = try #require(
            BarMotion.pocketSink(
                edge: .left,
                side: 40,
                travel: Self.travel,
                from: Self.drawn(0.3, edge: .left),
                reduceMotion: false
            )
        )
        #expect(abs(part.duration - 0.3 * BarMotion.pocketSinkSpan) < 1e-6)
        #expect(!sink.isRemovedOnCompletion)
        let to = try #require((sink.toValue as? NSValue)?.caTransform3DValue)
        #expect(
            CATransform3DEqualToTransform(
                to,
                BarMotion.pocketRiseStart(
                    edge: .left,
                    side: 40,
                    travel: Self.travel
                )
            )
        )
    }
}
