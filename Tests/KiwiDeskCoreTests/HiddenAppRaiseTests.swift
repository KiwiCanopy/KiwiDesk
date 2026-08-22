import Foundation
import Testing

@testable import KiwiDeskCore

/// The close-return raise stands down when the removal is a
/// hide (#913).
///
/// Routing the hide drop through the destroy fold buys the
/// fold's close-return arm along with its layout half — and
/// that arm calls `focusWindow(next, warp: true)`. On a ⌘H that
/// is KiwiDesk raising its own pick and dragging the pointer
/// after it, concurrently with macOS activating whichever app
/// IT chose, on a keystroke that never moved the mouse. The
/// layout half is wanted; the focus half is not.
///
/// **Why a needle and not a behavior test.** The raise site is
/// gated on `eventLoop.isListed`, which calls live AX
/// (`AXHelper.windows(pid:)`, not the injected seam), so for a
/// fabricated pid the whole block is unreachable and a driven
/// `handle(.windowDestroyed(…))` raises nothing — a behavior
/// assertion here would pass with the stand-down deleted, and
/// its control would pass with close-return focus deleted
/// outright. That gate is the same limit
/// `KiwiCore+CloseReturnRestack`'s doc names. So the fold half
/// is pinned by behavior below, and the raise half by a needle,
/// which is the shape `StartupSweepWiringTests` and
/// `ZOrderSequenceWiringTests` use for a production decision no
/// unit test can reach. That needle is
/// `HiddenAppRaiseWiringTests`, in the GUI target because that
/// is where `SourceScan` lives — it scans both trees.
@Suite("Hidden-app raise stand-down (#913)")
struct HiddenAppRaiseTests {
    @Test("only a hide reads as a hide drop")
    func predicateIsExactlyTheHide() {
        #expect(KiwiEvent.windowHidden(WindowID(1)).isHideDrop)
        #expect(
            !KiwiEvent.windowDestroyed(
                WindowID(1),
                wasMinimized: false
            ).isHideDrop
        )
        // The parked case is not a hide either: a minimize
        // SHOULD hand focus on, and it always has.
        #expect(
            !KiwiEvent.windowDestroyed(
                WindowID(1),
                wasMinimized: true
            ).isHideDrop
        )
    }
}
