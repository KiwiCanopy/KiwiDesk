import Foundation
import Testing

@testable import KiwiDeskCore

/// #465 QA regression: raising same-app window B activates the
/// app, and a lazy-AX app re-reports its OLD focused window A
/// on a hidden space; following that report yanked the user
/// back to A's space. While a same-app raise is RECENT
/// (`selfRaiseStamps`, age-bounded), the sibling report is
/// distrusted: no follow, state focus reverted. Visible and
/// sticky siblings, other apps, and expired stamps all pass
/// through untouched. Split from
/// `SpaceSwitchFocusHandoffTests` (suite-size rule).
@Suite("Activation re-report distrust (#465)", .serialized)
@MainActor
struct ActivationReReportTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-rereport-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        pid: pid_t = 1
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: pid,
                    appName: "App\(pid)"
                )
            )
        )
    }

    /// Window 1 (pid 5) hidden on space 2; window 2 (pid 5)
    /// stays the active space's focus — the raised target.
    private func seedHiddenSibling(_ core: KiwiCore) {
        addWindow(core, 1, pid: 5)
        addWindow(core, 2, pid: 5)
        core.moveWindow(
            WindowID(1),
            to: SpaceID(2),
            follow: false
        )
    }

    @Test("Stale same-app re-report neither follows nor moves")
    func reReportSuppressed() {
        let core = makeCore()
        seedHiddenSibling(core)
        #expect(core.state.workspaces.lastFocused == WindowID(2))
        core.selfRaiseStamps[WindowID(2)] = Date()
        core.handle(.windowFocused(WindowID(1)))
        // No focus-follow scheduled, focus stays reverted.
        #expect(core.deferred.task(for: .focusFollow) == nil)
        #expect(core.state.workspaces.lastFocused == WindowID(2))
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
    }

    /// Control: with no recent same-app raise, the same report
    /// schedules the normal cmd-tab focus-follow — the
    /// suppression is provenance-scoped, not a blanket mute.
    @Test("A clean hidden-window report still schedules follow")
    func cleanReportStillFollows() {
        let core = makeCore()
        seedHiddenSibling(core)
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }

    /// A raise in flight for a DIFFERENT app never suppresses.
    @Test("Another app's raise does not suppress the follow")
    func otherAppRaiseDoesNotSuppress() {
        let core = makeCore()
        seedHiddenSibling(core)
        addWindow(core, 3, pid: 9)
        core.selfRaiseStamps[WindowID(3)] = Date()
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }

    /// An EXPIRED stamp never suppresses (review): a raise that
    /// emitted no echo must not poison the app's hidden windows
    /// beyond `selfRaiseSiblingWindow` — a later cmd-tab to the
    /// sibling follows normally.
    @Test("An expired raise stamp does not suppress the follow")
    func expiredStampDoesNotSuppress() {
        let core = makeCore()
        seedHiddenSibling(core)
        core.selfRaiseStamps[WindowID(2)] = Date(
            timeIntervalSinceNow:
                -KiwiCore.selfRaiseSiblingWindow - 1
        )
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }

    /// A same-app sibling the user can SEE (a window on the
    /// ACTIVE space) is a genuine click, never a stale
    /// re-report — state focus moves to it (review).
    @Test("A visible same-app sibling focus is honored")
    func visibleSiblingFocusHonored() {
        let core = makeCore()
        addWindow(core, 1, pid: 5)
        addWindow(core, 2, pid: 5)
        // Both on the active space; 2 focused and stamped.
        core.selfRaiseStamps[WindowID(2)] = Date()
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.state.workspaces.lastFocused == WindowID(1))
    }

    /// A sticky sibling is exempt (review): `space(of:)` is
    /// only its hidden HOME — the window itself renders
    /// visibly (#414), and the follow is sticky-exempt anyway,
    /// so its focus must be honored, not reverted.
    @Test("A sticky sibling's focus is honored, not reverted")
    func stickySiblingFocusHonored() {
        let core = makeCore()
        addWindow(core, 1, pid: 5)
        addWindow(core, 2, pid: 5)
        var sticky = ManagedWindow(
            id: WindowID(3),
            pid: 5,
            appName: "App5",
            stickyScope: .global
        )
        sticky.isFloating = true
        core.state.apply(.windowCreated(sticky))
        // Home the sticky on a hidden space; focus back to 2.
        core.moveWindow(
            WindowID(3),
            to: SpaceID(2),
            follow: false
        )
        core.state.apply(.windowFocused(WindowID(2)))
        core.selfRaiseStamps[WindowID(2)] = Date()
        core.handle(.windowFocused(WindowID(3)))
        // Honored: the sticky becomes the real focus.
        #expect(core.state.workspaces.lastFocused == WindowID(3))
    }
}
