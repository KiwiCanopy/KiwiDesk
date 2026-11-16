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
                rise: entry,
                from: nil,
                reduceMotion: false
            )
        )
        #expect(abs(scrub.beginTime - ShelfReveal.revealDelay) < 1e-6)
        #expect(abs(scrub.duration - PocketRiseTimeline.span) < 1e-6)
        #expect(scrub.fillMode == .both)
        #expect(!scrub.isRemovedOnCompletion)
        // Taken over mid-flight, it runs from where it stands at once.
        let taken = try #require(
            BarMotion.pocketScrub(
                edge: .bottom,
                side: 40,
                rise: entry,
                from: CATransform3DIdentity,
                reduceMotion: false
            )
        )
        #expect(taken.beginTime == 0)
        #expect(abs(taken.duration - entry.length) < 1e-6)
    }

    @Test("Reduce Motion scrubs and sinks nothing")
    func reducedHoldsStill() {
        #expect(
            BarMotion.pocketScrub(
                edge: .bottom,
                side: 40,
                rise: fill(ShelfReveal.dwellDelay),
                from: nil,
                reduceMotion: true
            ) == nil
        )
        #expect(
            BarMotion.pocketSink(
                edge: .bottom,
                side: 40,
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
                from: CATransform3DIdentity,
                reduceMotion: false
            )
        )
        #expect(sink.duration == BarMotion.pocketSinkSpan)
        #expect(!sink.isRemovedOnCompletion)
        let to = try #require((sink.toValue as? NSValue)?.caTransform3DValue)
        #expect(
            CATransform3DEqualToTransform(
                to,
                BarMotion.pocketRiseStart(edge: .left, side: 40)
            )
        )
    }
}
