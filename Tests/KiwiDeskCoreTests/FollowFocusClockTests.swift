import Foundation
import Testing

@testable import KiwiDeskCore

/// Both arrival debts age on the core's `wallClock` (#2341), so a
/// test core's frozen clock keeps them live however long the
/// runner takes, and only moving that clock expires them.
@MainActor
@Suite("Arrival debts age on the core's clock")
struct FollowFocusClockTests {
    private let window = WindowID(900_301)

    @Test("a frozen clock keeps the debt; moving it expires it")
    func debtsAgeOnTheCoreClock() {
        let core = makeTestCore()
        let start = core.wallClock()
        for debt in [core.followFocus, core.desktopMemory.returnFocus] {
            core.wallClock = { start }
            debt.record(window)
            core.wallClock = {
                start.addingTimeInterval(
                    FollowFocusIntent.drainWindow - 1
                )
            }
            #expect(debt.owed() == window)
            core.wallClock = {
                start.addingTimeInterval(FollowFocusIntent.drainWindow)
            }
            #expect(debt.owed() == nil)
        }
    }
}
