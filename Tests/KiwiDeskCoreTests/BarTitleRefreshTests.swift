import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A title change is a RENDER input for the bars and nothing
/// more. This suite is the only net over that: the event was
/// deliberately inert before (`shouldRetile` returns false for
/// it, and the handler did nothing unless a late title flipped a
/// remembered float), so a revert to inert breaks no other test.
///
/// The bars here are PAINTED through the managers rather than
/// built by the drivers, because that is exactly what the gate
/// reads (`AppBarManager.showsTitle(of:)`). It is also what keeps
/// this suite off the machine: the version that seeded state and
/// let the gate re-derive the on-screen spaces was green only
/// because an unregistered display fails open to `true` on a dev
/// host (review 2026-08-20, `tests.md` on injected seams). The
/// drivers' own agreement with what they paint belongs to
/// `FullscreenStandDownTests` and the driver suites.
@Suite("Bar title refresh", .serialized)
@MainActor
struct BarTitleRefreshTests {
    /// One window, on one painted App Bar that draws text.
    private func seeded(
        content: AppBarStyle.Content = .iconAndTitle,
        edge: AppBarEdge = .top,
        count: Int = 1,
        front: WindowID? = nil
    ) -> KiwiCore {
        let core = makeBarCore()
        core.state.workspaces.assign(SpaceID("1"), to: barTitleDisplay)
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(
            .windowCreated(titledWindow(1, title: "Downloads"))
        )
        core.state.apply(.windowFocused(WindowID(1)))
        core.appBars.sync([
            paintedAppBar(
                content: content,
                edge: edge,
                items: [
                    appBarItem(1, text: "Downloads", count: count)
                ]
            )
        ])
        core.spaceBars.sync(
            front == nil ? [] : [paintedSpaceBar(front: front)]
        )
        return core
    }

    @Test("A title change on a text-drawing bar schedules one")
    func titleChangeSchedules() {
        let core = seeded()
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)
    }

    /// The gate is what keeps a keystroke off the render path
    /// for everyone who does not draw titles.
    @Test("An icon-only bar schedules nothing")
    func iconOnlySchedulesNothing() {
        let core = seeded(content: .icon)
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// A vertical bar RENDERS icon-only whatever the stored
    /// preference says, so the gate asks the painted bar's
    /// `renderedContent` — the raw preference would schedule a
    /// refresh for a bar that cannot show a title.
    @Test("A vertical bar schedules nothing")
    func verticalSchedulesNothing() {
        let core = seeded(edge: .left)
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// A collapsed group draws its APP NAME, never a member's
    /// title (`KiwiCore.barItemText`), so a rename inside one
    /// changes nothing on screen. Exact here only because the
    /// gate reads the painted groups; the state-derived version
    /// could not afford the question and deliberately
    /// over-scheduled.
    @Test("A collapsed group schedules nothing")
    func collapsedGroupSchedulesNothing() {
        let core = seeded(count: 2)
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// A window that is on no painted bar is the common case and
    /// must stay free.
    @Test("An untracked window schedules nothing")
    func untrackedSchedulesNothing() {
        let core = seeded()
        core.handleTitleChangedForBars(WindowID(999))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// Every reason a bar is absent — disabled, empty, on a
    /// hidden space, on a fullscreen desktop, on a display with
    /// no screen — arrives here as the same fact: nothing was
    /// painted. That collapse is the point of reading the
    /// painted record instead of re-deriving five gates.
    @Test("No painted bar schedules nothing")
    func noPaintedBarSchedulesNothing() {
        let core = seeded()
        core.appBars.sync([])
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// The Space Bar's front segment is a second reason to
    /// refresh, independent of the App Bar.
    @Test("The front segment arms the refresh on its own")
    func frontSegmentArms() {
        let core = seeded(content: .icon, front: WindowID(1))
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)
    }

    /// A VERTICAL Space Bar draws no front name but still
    /// ANNOUNCES one: `SpaceBarOverlay` builds the segment's
    /// accessibility label from the same title on every edge. The
    /// gate stood down here until a review found it (2026-08-20),
    /// which left VoiceOver reading a title that stopped updating
    /// until the next retile.
    @Test("A vertical Space Bar still arms it")
    func verticalSpaceBarStillArms() {
        let core = seeded(content: .icon)
        core.spaceBars.sync([
            paintedSpaceBar(edge: .left, front: WindowID(1))
        ])
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)
    }

    @Test("The front segment toggle gates it")
    func frontSegmentOffDoesNotArm() {
        let core = seeded(content: .icon, front: nil)
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// The segment is about ONE window, so another window's
    /// rename is not its business.
    @Test("Another window's title leaves the segment alone")
    func otherWindowDoesNotArmTheSegment() {
        let core = seeded(content: .icon, front: WindowID(2))
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// A burst is one refresh, not twenty: each change cancels
    /// the pending pass and schedules its own, so only the last
    /// one survives to fire.
    ///
    /// Asserted on task IDENTITY and `isCancelled` rather than on
    /// a count, because that is what the debounce actually
    /// claims — and because a body that never runs would satisfy
    /// any count-based version of this.
    @Test("A burst debounces down to one live refresh")
    func burstDebounces() throws {
        let core = seeded()
        core.handleTitleChangedForBars(WindowID(1))
        let first = try #require(
            core.deferred.task(for: .barTitleRefresh)
        )
        core.handleTitleChangedForBars(WindowID(1))
        let second = try #require(
            core.deferred.task(for: .barTitleRefresh)
        )
        #expect(first != second, "the slot must be replaced")
        #expect(first.isCancelled, "the superseded pass must die")
        #expect(!second.isCancelled)
    }

    /// Teardown reaches it, because it is a `DeferredTasks` slot
    /// rather than a bespoke dispatch hop — the #48 argument.
    @Test("Teardown cancels a pending refresh")
    func teardownCancels() {
        let core = seeded()
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)
        core.deferred.cancelAll()
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// A title moves no window. If this ever flips, every
    /// keystroke in an editor re-issues a frame set — and on an
    /// app that refuses a size, re-teaches the #677 ledger.
    @Test("A title change is not a retile")
    func titleIsNeverARetile() {
        #expect(
            !TilingEngine.shouldRetile(
                after: .windowTitleChanged(WindowID(1), "Anything")
            )
        )
    }

    // MARK: - The production wiring

    /// The event actually REACHES the gate.
    ///
    /// Every test above calls `handleTitleChangedForBars`
    /// directly, which proves the gate and nothing about whether
    /// anything calls it. Deleting the `else` arm in
    /// `KiwiCore+Events` — reverting this feature's entire
    /// production wiring — left all 3622 tests green
    /// (guard-prover, 2026-08-19): the `tests.md` shape where a
    /// production decision no unit test reaches hides behind a
    /// suite that reads the feature without discriminating it.
    @Test("A title event reaches the bars through handle()")
    func eventReachesTheGate() {
        let core = seeded()
        core.handle(
            .windowTitleChanged(WindowID(1), "Renamed")
        )
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)
    }

    /// ...and the state fold ran first, so the refresh that
    /// fires reads the NEW title instead of re-rendering the old
    /// one.
    @Test("The event folds the new title before refreshing")
    func eventFoldsBeforeRefreshing() {
        let core = seeded()
        core.handle(
            .windowTitleChanged(WindowID(1), "Renamed")
        )
        #expect(
            core.state.windows[WindowID(1)]?.title == "Renamed"
        )
    }

    /// The gate is consulted from `handle`, not bypassed by it.
    @Test("handle() honours the gate")
    func handleHonoursTheGate() {
        let core = seeded(content: .icon)
        core.handle(
            .windowTitleChanged(WindowID(1), "Renamed")
        )
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }
}
