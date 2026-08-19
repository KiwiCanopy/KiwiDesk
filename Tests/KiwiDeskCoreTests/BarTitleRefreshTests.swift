import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A drawn title makes `.windowTitleChanged` a RENDER input for
/// the bars — and only a render one.
///
/// This suite is the only net over that. The event was
/// deliberately inert before this change (`shouldRetile` returns
/// false for it, and the handler did nothing unless a late title
/// flipped a remembered float), so a revert to inert breaks no
/// other test.
@MainActor
private func makeBarCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

private func titledWindow(
    _ id: UInt32,
    app: String = "Finder",
    title: String
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: app,
        title: title,
        isFloating: false
    )
}

/// A title change is a RENDER input for the bars and nothing
/// more. This suite is the only net over that: the event was
/// deliberately inert before, so a revert to inert is otherwise
/// silent.
@Suite("Bar title refresh", .serialized)
@MainActor
struct BarTitleRefreshTests {
    private let display = DisplayID(7)

    /// One monocle space on one display, its App Bar enabled and
    /// drawing text, holding one window.
    private func seeded(
        content: AppBarStyle.Content = .iconAndTitle,
        edge: AppBarEdge = .top
    ) -> KiwiCore {
        let core = makeBarCore()
        // REGISTER the display, not just the space->display
        // mapping: `assign` alone leaves `allDisplays` empty, and
        // `showingSpaces()` then takes its cold-start fallback —
        // so every gate test below would exercise the fallback
        // branch and prove nothing about the per-display
        // resolution or the #670 stand-down (found by mutating
        // that branch and watching this suite stay green,
        // 2026-08-19).
        core.state.workspaces.upsertDisplay(
            Display(
                id: display,
                name: "Test",
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            )
        )
        // Pin the Space Bar defaults this fixture reasons from
        // (#660 moved this type's default edge once, and
        // `frontSegmentArms` / the three "schedules nothing"
        // tests are green only because of these three values).
        #expect(SpaceBarStyle().enabled)
        #expect(SpaceBarStyle().edge == .top)
        #expect(!SpaceBarStyle().showFrontApp)
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.activate(SpaceID("1"))
        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        core.tiler.settings.monocle.appBar.enabled = true
        core.tiler.settings.appBarStyle.content = content
        core.tiler.settings.appBarStyle.edge = edge
        core.state.apply(
            .windowCreated(titledWindow(1, title: "Downloads"))
        )
        core.state.apply(.windowFocused(WindowID(1)))
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
    /// preference says, so the gate must ask the rendered
    /// content — asking the raw preference would schedule a
    /// refresh for a bar that cannot show a title.
    @Test("A vertical bar schedules nothing")
    func verticalSchedulesNothing() {
        let core = seeded(edge: .left)
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// A window that is on no shown bar is the common case and
    /// must stay free.
    @Test("An untracked window schedules nothing")
    func untrackedSchedulesNothing() {
        let core = seeded()
        core.handleTitleChangedForBars(WindowID(999))
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

    /// A bar the layout does not show schedules nothing. The
    /// gate reads `host.appBar.enabled`, and no other fixture
    /// ever seeds a DISABLED bar — dropping that check was inert
    /// (guard-prover, 2026-08-19).
    @Test("A disabled App Bar schedules nothing")
    func disabledAppBarSchedulesNothing() {
        let core = seeded()
        core.tiler.settings.monocle.appBar.enabled = false
        core.tiler.settings.spaceBarStyle.showFrontApp = false
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// The Space Bar's own on/off switch, likewise.
    @Test("A disabled Space Bar schedules nothing")
    func disabledSpaceBarSchedulesNothing() {
        let core = seeded(content: .icon)
        core.tiler.settings.spaceBarStyle.showFrontApp = true
        core.tiler.settings.spaceBarStyle.enabled = false
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// `verticalSchedulesNothing` covers the App Bar's vertical
    /// leg; the Space Bar has an identical one, because
    /// `layoutFrontName` returns early on a vertical bar and so
    /// draws no title to refresh.
    @Test("A vertical Space Bar schedules nothing")
    func verticalSpaceBarSchedulesNothing() {
        let core = seeded(content: .icon)
        core.tiler.settings.spaceBarStyle.showFrontApp = true
        core.tiler.settings.spaceBarStyle.edge = .left
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// Only the space a display is SHOWING counts. A window on
    /// another Desktop is the common case the gate exists to
    /// drop, and `showingSpaces()` returning every space instead
    /// of the current one was inert.
    @Test("A window on a non-showing space schedules nothing")
    func hiddenSpaceSchedulesNothing() {
        let core = seeded()
        core.tiler.settings.spaceBarStyle.showFrontApp = false
        // A second space on the same display, not current, with
        // its own window.
        core.state.workspaces.assign(SpaceID("2"), to: display)
        core.state.workspaces.setMode(SpaceID("2"), .monocle)
        core.state.windows.upsert(
            titledWindow(2, title: "Elsewhere")
        )
        core.state.workspaces.add(WindowID(2), to: "2")
        core.handleTitleChangedForBars(WindowID(2))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
        // ...while the showing space's own window still does.
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)
    }

    /// The Space Bar's front segment is a second reason to
    /// refresh, and it is gated on its own toggle.
    @Test("The front segment arms the refresh on its own")
    func frontSegmentArms() {
        let core = seeded(content: .icon)
        core.tiler.settings.spaceBarStyle.showFrontApp = true
        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)
    }

    @Test("The front segment toggle gates it")
    func frontSegmentOffDoesNotArm() {
        let core = seeded(content: .icon)
        core.tiler.settings.spaceBarStyle.showFrontApp = false
        core.handleTitleChangedForBars(WindowID(1))
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
        core.tiler.settings.spaceBarStyle.showFrontApp = false
        core.handle(
            .windowTitleChanged(WindowID(1), "Renamed")
        )
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }
}

/// That the debounced pass DOES something.
///
/// `burstDebounces` asserts on task identity, which an empty body
/// satisfies — emptying `runBarTitleRefresh()` was inert across
/// every test in the new suites (guard-prover, 2026-08-19). The
/// only honest observation is the rendered item text, which is
/// the one thing the refresh exists to change.
///
/// Its own suite because its fixture differs on purpose: no
/// display is assigned, so `updateAppBar` takes its documented
/// cold-start fallback to the main screen and can build a real
/// bar without a `DisplayID` that happens to match this host's.
@Suite("Bar title refresh output", .serialized)
@MainActor
struct BarTitleRefreshOutputTests {
    private func seededOnMainScreen() -> KiwiCore {
        let core = makeBarCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        core.tiler.settings.monocle.appBar.enabled = true
        core.tiler.settings.appBarStyle.content = .iconAndTitle
        core.tiler.settings.appBarStyle.edge = .top
        core.state.apply(
            .windowCreated(titledWindow(1, title: "Downloads"))
        )
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    @Test("The refresh re-renders the bar with the new title")
    func refreshRedrawsTheItem() throws {
        let core = seededOnMainScreen()
        core.updateAppBar()
        // `#require`, not `if let`: a fixture that built no bar
        // would make every assertion below pass vacuously, which
        // is the failure this whole suite exists to rule out.
        let before = try #require(
            core.appBars.shownBarsForTesting.first?.items.first
        )
        #expect(before.text == "Downloads")

        core.state.apply(
            .windowTitleChanged(WindowID(1), "Projects")
        )
        core.runBarTitleRefresh()

        let after = try #require(
            core.appBars.shownBarsForTesting.first?.items.first
        )
        #expect(after.text == "Projects")
    }
}
