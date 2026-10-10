import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The slow-boot notice through a restart restore (#2133): it
/// outlives ready while windows are put back, shows only past the
/// boot threshold, holds its end line, and hides at once when the
/// restore is dropped.
@Suite("Boot notice restore line (#2133)")
struct BootNoticeRestoreTests {
    private typealias T = BootNoticeTimeline
    private let scanning = BootPhase.scanning(scanned: 3, total: 40)
    private let placing = RestorePhase.placing(placed: 6, total: 12)
    private let done = RestorePhase.done(placed: 11, total: 12)
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Shown at 12 after a boot that began at 10, now restoring.
    private func restoringShown() -> T {
        var timeline = T()
        _ = timeline.phase(scanning, at: 10, standsDown: false)
        timeline.shown(at: 12)
        _ = timeline.restore(placing, at: 13)
        return timeline
    }

    @Test("ready keeps a restoring notice up")
    func readyKeepsItUp() {
        var timeline = restoringShown()
        #expect(timeline.phase(.ready, at: 14, standsDown: false) == .none)
        #expect(timeline.restoring)
    }

    @Test("a fast boot shows only if the restore still runs at the threshold")
    func fastBootWaitsForTheThreshold() {
        var timeline = T()
        _ = timeline.phase(scanning, at: 10, standsDown: false)
        #expect(timeline.restore(placing, at: 11) == .showAt(10 + T.threshold))
        _ = timeline.phase(.ready, at: 11.5, standsDown: false)
        #expect(timeline.showsAt(10 + T.threshold, standsDown: false))
        #expect(!timeline.showsAt(10 + T.threshold - 0.1, standsDown: false))
        var ended = timeline
        #expect(ended.restore(done, at: 12) == .cancel)
        #expect(!ended.showsAt(10 + T.threshold, standsDown: false))
    }

    @Test("the end line is held before it hides")
    func endIsHeld() {
        var timeline = restoringShown()
        _ = timeline.phase(.ready, at: 14, standsDown: false)
        #expect(timeline.restore(done, at: 40) == .hideAt(40 + T.minimumShown))
        #expect(!timeline.restoring)
    }

    @Test("a dropped restore hides at once, and only a running one")
    func droppedHidesNow() {
        var timeline = restoringShown()
        #expect(timeline.restore(.none, at: 20) == .hideNow)
        var idle = T()
        #expect(idle.restore(.none, at: 20) == .none)
        #expect(idle.restore(done, at: 20) == .none)
    }

    @Test("the restore lines put the count last")
    @MainActor
    func linesPutTheCountLast() {
        LocalizationManager.shared.select("en")
        #expect(BootCountText.line(for: RestorePhase.none) == nil)
        #expect(
            BootCountText.line(for: placing)
                == "Putting your windows back: 6 of 12"
        )
        #expect(
            BootCountText.line(for: done) == "Your windows are back: 11 of 12"
        )
    }

    @Test("the app feeds the restore to the notice")
    func appFeedsTheRestore() throws {
        let delegate = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate.swift"
            )
        )
        let wiring = """
            core.onRestorePhaseChange = { [weak self] phase in
                self?.bootNotice.restore(phase)
            }
            """
        #expect(
            delegate.filter { !$0.isWhitespace }
                .contains(wiring.filter { !$0.isWhitespace })
        )
    }
}
