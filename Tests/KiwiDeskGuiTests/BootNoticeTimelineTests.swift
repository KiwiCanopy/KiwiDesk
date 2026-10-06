import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// When the slow-boot notice shows and leaves (#1715): only past
/// the threshold, never before boot leaves idle, and once shown at
/// least the minimum, so it never flickers.
@Suite("Slow-boot notice timeline (#1715)")
struct BootNoticeTimelineTests {
    private let scanning = BootPhase.scanning(scanned: 3, total: 40)

    @Test("the show is due at the threshold after boot begins")
    func showIsDueAtTheThreshold() {
        var timeline = BootNoticeTimeline()
        #expect(timeline.phase(.idle, at: 5) == nil)
        let due = timeline.phase(scanning, at: 10)
        #expect(due == 10 + BootNoticeTimeline.threshold)
        #expect(!timeline.showsAt(11.9))
        #expect(timeline.showsAt(12))
        // A later count does not push the show back.
        #expect(timeline.phase(scanning, at: 11) == nil)
    }

    @Test("a boot ready before the threshold never shows")
    func readyBeforeThresholdNeverShows() {
        var timeline = BootNoticeTimeline()
        _ = timeline.phase(scanning, at: 10)
        _ = timeline.phase(.ready, at: 11.5)
        #expect(!timeline.showsAt(12))
        #expect(timeline.hideTime(readyAt: 11.5) == nil)
    }

    @Test("a shown notice stays at least the minimum")
    func shownNoticeHoldsTheMinimum() {
        var timeline = BootNoticeTimeline()
        _ = timeline.phase(scanning, at: 10)
        timeline.shown(at: 12)
        #expect(!timeline.showsAt(12.5))
        let minimum = BootNoticeTimeline.minimumShown
        #expect(timeline.hideTime(readyAt: 12.3) == 12 + minimum)
        #expect(timeline.hideTime(readyAt: 20) == 20)
    }
}
