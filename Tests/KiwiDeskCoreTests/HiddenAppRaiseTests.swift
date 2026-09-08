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
/// Since #935 the hide is one arm of the ONE stand-down
/// predicate
/// (`EventLoop.closeReturnRaiseStandsDown(after:departedWithDesktop:)`,
/// behavior-tested in `OwnDialogFocusTests`); this suite keeps
/// the event classification itself pinned. The raise site that
/// asks the predicate is pinned by
/// `CloseReturnStandDownWiringTests` — a needle, because the
/// raise's AX call needs a live element a fabricated pid never
/// has, so a driven `handle(.windowDestroyed(…))` observes no
/// raise either way.
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
