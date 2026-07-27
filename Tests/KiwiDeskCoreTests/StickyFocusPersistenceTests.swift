import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Sticky windows are focusable from every space (#414): a
/// focus landing on one whose HOME space is inactive must NOT
/// pull that space forward — following it yanked the user back
/// to the origin space on every interaction (the QA fly-back).
@Suite("Sticky focus follow", .serialized)
@MainActor
struct StickyFocusFollowTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-follow-\(UUID().uuidString)"
                )
        )
    }

    private func seed(_ core: KiwiCore) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "App"
                )
            )
        )
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.activate(SpaceID(2))
    }

    @Test("A foreign sticky focus schedules no follow")
    func stickyExempt() {
        let core = makeCore()
        seed(core)
        core.state.setSticky(WindowID(1), .global)
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.deferred.task(for: .focusFollow) == nil)
        #expect(
            core.state.workspaces.activeSpace == SpaceID(2)
        )
    }

    @Test("A foreign non-sticky focus still follows")
    func nonStickyFollows() {
        let core = makeCore()
        seed(core)
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }
}

/// Close/reopen persistence of the sticky intent (#414),
/// mirroring the float persistence (#160): identity is app +
/// title, an empty title carries no identity, and the last
/// close wins for a shared identity.
@Suite("Sticky persistence")
struct StickyPersistenceTests {
    private func makeWindow(
        _ id: UInt32,
        pid: pid_t = 100,
        title: String = "Doc"
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "TestApp",
            title: title
        )
    }

    @Test("make_sticky survives close and reopen")
    func stickySurvivesReopen() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isSticky == true)
    }

    @Test("an unsticky close clears a stale remembered intent")
    func unstickyCloseClears() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        // Reopen restores sticky; the user then turns it off.
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isSticky == true)
        state.setSticky(WindowID(2), .none)
        state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(3)))
        #expect(state.windows[WindowID(3)]?.isSticky == false)
    }

    @Test("app termination remembers sticky for relaunch")
    func appTerminationRemembers() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(.appTerminated(pid: 100))
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isSticky == true)
    }

    @Test("a late-loading title still restores the intent")
    func lazyTitleRestores() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2, title: "")))
        #expect(state.windows[WindowID(2)]?.isSticky == false)
        state.apply(.windowTitleChanged(WindowID(2), "Doc"))
        #expect(state.windows[WindowID(2)]?.isSticky == true)
    }

    @Test("empty titles carry no identity to remember")
    func emptyTitleNeverRemembered() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1, title: "")))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2, title: "")))
        #expect(state.windows[WindowID(2)]?.isSticky == false)
    }

    @Test("the restored intent re-arms for the next cycle")
    func restoredIntentRearms() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(3)))
        #expect(state.windows[WindowID(3)]?.isSticky == true)
    }

    @Test("untracked ids never record an intent")
    func untrackedIdIgnored() {
        var state = StateCoordinator()
        state.setSticky(WindowID(9), .global)
        state.apply(.windowCreated(makeWindow(9)))
        #expect(state.windows[WindowID(9)]?.isSticky == false)
    }

    @Test("a rekey carries the sticky flag to the new id")
    func rekeyCarriesFlag() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowRekeyed(WindowID(1), WindowID(2))
        )
        #expect(state.windows[WindowID(2)]?.isSticky == true)
    }
}
