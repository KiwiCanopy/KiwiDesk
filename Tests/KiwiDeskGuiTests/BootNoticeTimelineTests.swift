import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every decision the slow-boot notice makes (#1715): only past
/// the threshold, never before boot leaves idle, at least the
/// minimum once shown, down for good once a stand-down meets it,
/// and afresh for each boot.
@Suite("Slow-boot notice timeline (#1715)")
struct BootNoticeTimelineTests {
    private typealias T = BootNoticeTimeline
    private let scanning = BootPhase.scanning(scanned: 3, total: 40)

    /// A timeline shown at 12, after a boot that began at 10.
    private func shown() -> T {
        var timeline = T()
        _ = timeline.phase(scanning, at: 10, standsDown: false)
        timeline.shown(at: 12)
        return timeline
    }

    @Test("the show is due at the threshold after boot begins")
    func showIsDueAtTheThreshold() {
        var timeline = T()
        #expect(timeline.phase(.idle, at: 5, standsDown: false) == .cancel)
        let effect = timeline.phase(scanning, at: 10, standsDown: false)
        #expect(effect == .showAt(10 + T.threshold))
        #expect(!timeline.showsAt(11.9, standsDown: false))
        #expect(timeline.showsAt(12, standsDown: false))
        #expect(!timeline.showsAt(12, standsDown: true))
        // A later count does not push the show back.
        #expect(timeline.phase(scanning, at: 11, standsDown: false) == .none)
        #expect(timeline.showsAt(12, standsDown: false))
    }

    @Test("a boot ready before the threshold never shows")
    func readyBeforeThresholdNeverShows() {
        var timeline = T()
        _ = timeline.phase(scanning, at: 10, standsDown: false)
        #expect(timeline.phase(.ready, at: 11.5, standsDown: false) == .cancel)
        #expect(!timeline.showsAt(12, standsDown: false))
    }

    @Test("a shown notice stays at least the minimum")
    func shownNoticeHoldsTheMinimum() {
        var early = shown()
        #expect(
            early.phase(.ready, at: 12.3, standsDown: false)
                == .hideAt(12 + T.minimumShown)
        )
        var late = shown()
        #expect(late.phase(.ready, at: 20, standsDown: false) == .hideAt(20))
    }

    @Test("a stand-down while shown hides it for the rest of the boot")
    func standDownHidesForGood() {
        var timeline = shown()
        #expect(timeline.phase(scanning, at: 13, standsDown: true) == .hideNow)
        #expect(timeline.phase(scanning, at: 14, standsDown: false) == .none)
        #expect(timeline.phase(.ready, at: 15, standsDown: false) == .cancel)
    }

    @Test("a stand-down before the show cancels it")
    func standDownBeforeShowCancels() {
        var timeline = T()
        _ = timeline.phase(scanning, at: 10, standsDown: false)
        #expect(timeline.phase(scanning, at: 11, standsDown: true) == .cancel)
        #expect(!timeline.showsAt(12, standsDown: false))
    }

    @Test("a stop hides a shown notice and the next boot starts over")
    func stopHidesAndResets() {
        var timeline = shown()
        #expect(timeline.phase(.idle, at: 13, standsDown: false) == .hideNow)
        let effect = timeline.phase(scanning, at: 30, standsDown: false)
        #expect(effect == .showAt(30 + T.threshold))
        #expect(timeline.showsAt(32, standsDown: false))
    }
}
