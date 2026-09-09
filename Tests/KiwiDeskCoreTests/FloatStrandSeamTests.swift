import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = FloatStrandFixture

/// The seams a lost capture crossed (#1352), each pinned at the
/// CONSUMER: the two `captureState` wirings, the session
/// restore's replay, the restore sweep's away exemption, and
/// the echo classifier's corner test. `FloatStrandRecoveryTests`
/// holds the decision; these hold who asks it.
@Suite("Stranded float seams (#1352)", .serialized)
@MainActor
struct FloatStrandSeamTests {
    @Test(
        "Both captureState seams take the session snapshot",
        .enabled(if: NSScreen.main != nil)
    )
    func captureStateSeamsTakeTheSessionSnapshot() throws {
        let core = try #require(
            F.makeCore(mode: .floating, frame: F.parked())
        )
        let original = F.original
        core.tiler.seedStash(F.window, frame: original)
        for capture in [
            core.crash.captureState, core.sleepWake.captureState,
        ] {
            let record = capture()?.windows.first {
                $0.windowID == F.window
            }
            #expect(record?.frame == original)
        }
    }

    @Test(
        "A restore seeds a parked float's record as its capture",
        .enabled(if: NSScreen.main != nil)
    )
    func restoreSeedsAParkedRecord() throws {
        let core = try #require(
            F.makeCore(mode: .floating, frame: F.parked())
        )
        // Boot shape: the scan's retile runs BEFORE the session
        // restore, so the recovery has already seeded a centred
        // capture. The record must outrank it.
        core.retile()
        #expect(core.tiler.stashOriginal(F.window) == F.centred)
        let original = F.original
        core.restore(
            StateSnapshot(
                windows: [
                    StateSnapshot.WindowRecord(
                        id: F.window,
                        frame: original
                    )
                ],
                spaces: [],
                activeSpace: nil
            )
        )
        #expect(core.tiler.stashOriginal(F.window) == original)
        // Seeded, not set: the state frame still reads the
        // corner, which is what the forced park that follows
        // would otherwise have overwritten the set with.
        #expect(
            core.state.windows[F.window]?.frame == F.parked()
        )
        core.retile()
        #expect(core.tiler.stashOriginal(F.window) == original)
    }

    @Test(
        "A restore leaves a record that is itself a corner alone",
        .enabled(if: NSScreen.main != nil)
    )
    func restoreRefusesACornerRecord() throws {
        let core = try #require(
            F.makeCore(mode: .floating, frame: F.parked())
        )
        core.restore(
            StateSnapshot(
                windows: [
                    StateSnapshot.WindowRecord(
                        id: F.window,
                        frame: F.parked(lift: 4)
                    )
                ],
                spaces: [],
                activeSpace: nil
            )
        )
        #expect(core.tiler.stashOriginal(F.window) == nil)
    }

    @Test(
        "The sweep keeps the capture of a window away on a Desktop",
        .enabled(if: NSScreen.main != nil)
    )
    func sweepKeepsAnAwayWindowsCapture() throws {
        let core = try #require(
            F.makeCore(mode: .floating, frame: F.parked())
        )
        let away = WindowID(7)
        let departed = WindowID(8)
        let original = F.original
        core.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: 1,
            appName: "A",
            appBundleID: nil,
            nativeSpace: 1
        )
        core.tiler.seedStash(away, frame: original)
        core.tiler.seedStash(departed, frame: original)
        core.retile()
        #expect(core.tiler.stashOriginal(away) == original)
        // Neither tracked nor away: gone for good, swept.
        #expect(core.tiler.stashOriginal(departed) == nil)
    }

    @Test(
        "A lifted park echo keeps the capture; a real move drops it",
        .enabled(if: NSScreen.main != nil)
    )
    func liftedEchoKeepsTheCapture() throws {
        let core = try #require(
            F.makeCore(mode: .floating, frame: F.parked())
        )
        let original = F.original
        core.tiler.seedStash(F.window, frame: original)
        // No frame set was issued, so the applier's grace does
        // not vouch for this echo: only the corner test can.
        core.handle(.windowMoved(F.window, F.parked(lift: 4)))
        #expect(core.tiler.stashOriginal(F.window) == original)
        core.handle(
            .windowMoved(
                F.window,
                CGRect(x: 100, y: 100, width: 800, height: 600)
            )
        )
        #expect(core.tiler.stashOriginal(F.window) == nil)
    }
}
