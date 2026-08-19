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
}
