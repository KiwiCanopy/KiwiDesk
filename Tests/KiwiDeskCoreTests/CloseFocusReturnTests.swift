import Foundation
import Testing

@testable import KiwiDeskCore

// Close-return focus: closing the focused window hands focus
// back to the previously focused window (one-deep history,
// same space only), falling through to the successor-slot pick
// when the candidate is gone or unsurfaceable. The argument —
// and why this is not the repeat-press MRU cycling #637
// rejected — lives in `docs/design-decisions.md`
// ▸ Close-return focus.

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)

private func makeWindow(
    _ id: WindowID,
    isTransientOverlay: Bool = false
) -> ManagedWindow {
    ManagedWindow(
        id: id,
        pid: pid_t(id.raw),
        appName: "App\(id.raw)",
        isTransientOverlay: isTransientOverlay
    )
}

/// Pure state fixture: three windows in one space, focused in
/// creation order (the spawn grant routes through
/// `WorkspaceManager.focus`, so creates feed the history too).
private func makeState() -> StateCoordinator {
    var state = StateCoordinator()
    state.apply(.windowCreated(makeWindow(a)))
    state.apply(.windowCreated(makeWindow(b)))
    state.apply(.windowCreated(makeWindow(c)))
    return state
}

@Suite("Close-return focus")
struct CloseFocusReturnTests {
    @Test("Closing the focused window returns to the previous one")
    func closeReturnsToPrevious() {
        var state = makeState()
        state.apply(.windowFocused(a))
        state.apply(.windowFocused(c))
        // Successor of c's slot would be b (`windows.last`);
        // the history says a.
        state.apply(.windowDestroyed(c, wasMinimized: false))
        let home = state.workspaces.space(of: a)!
        #expect(state.workspaces[home]?.focused == a)
    }

    @Test("A dead candidate falls through to the successor slot")
    func deadCandidateFallsToSuccessor() {
        var state = makeState()
        state.apply(.windowFocused(a))
        state.apply(.windowFocused(b))
        // The candidate (a) dies first; closing b must then take
        // the forward successor (c), never index-minus-one.
        state.apply(.windowDestroyed(a, wasMinimized: false))
        state.apply(.windowDestroyed(b, wasMinimized: false))
        let home = state.workspaces.space(of: c)!
        #expect(state.workspaces[home]?.focused == c)
    }

    @Test("A minimized candidate falls through to the successor")
    func minimizedCandidateFallsToSuccessor() {
        var state = makeState()
        state.apply(.windowFocused(a))
        state.apply(.windowFocused(b))
        // A minimize surfaces as a destroy with the flag: the
        // candidate leaves state, and the close-return must not
        // un-park it (#673).
        state.apply(.windowDestroyed(a, wasMinimized: true))
        state.apply(.windowDestroyed(b, wasMinimized: false))
        let home = state.workspaces.space(of: c)!
        #expect(state.workspaces[home]?.focused == c)
    }

    @Test("A candidate in another space is never returned to")
    func crossSpaceCandidateIgnored() {
        var state = makeState()
        // A sticky-style focus into a foreign space (#414) can
        // put a foreign member into the history: s lives in
        // space 2, focused from there, then b in the home
        // space. Closing b must not yank across spaces.
        let s = WindowID(9)
        let homeOfA = state.workspaces.space(of: a)!
        state.workspaces.ensureSpace(SpaceID(2))
        state.workspaces.activate(SpaceID(2))
        state.apply(.windowCreated(makeWindow(s)))
        state.workspaces.activate(homeOfA)
        state.apply(.windowFocused(s))
        state.apply(.windowFocused(b))
        state.apply(.windowDestroyed(b, wasMinimized: false))
        #expect(state.workspaces[homeOfA]?.focused == c)
    }

    @Test("A transient-overlay candidate falls to the successor")
    func transientOverlayCandidateIgnored() {
        var state = StateCoordinator()
        let o = WindowID(7)
        state.apply(
            .windowCreated(makeWindow(o, isTransientOverlay: true))
        )
        state.apply(.windowCreated(makeWindow(b)))
        state.apply(.windowCreated(makeWindow(c)))
        // The overlay never got the spawn grant (#671), but a
        // genuine focus report can still put it in the history.
        state.apply(.windowFocused(o))
        state.apply(.windowFocused(b))
        state.apply(.windowDestroyed(b, wasMinimized: false))
        let home = state.workspaces.space(of: c)!
        #expect(state.workspaces[home]?.focused == c)
    }

    @Test("A fullscreen candidate falls to the successor")
    func fullscreenCandidateIgnored() {
        var state = makeState()
        state.apply(.windowFocused(a))
        state.apply(
            .windowFullscreenChanged(a, isFullscreen: true)
        )
        state.apply(.windowFocused(b))
        // Two nets share this outcome: the close-return refuses
        // the fullscreen candidate, and the #670 re-pick would
        // correct such a pick to the same successor — so this
        // pins the behavior, not which net caught it.
        state.apply(.windowDestroyed(b, wasMinimized: false))
        let home = state.workspaces.space(of: c)!
        #expect(state.workspaces[home]?.focused == c)
    }

    @Test("Closing the first window with no history stays first")
    func firstWindowNoHistoryStaysFirst() {
        var state = makeState()
        state.apply(.windowFocused(a))
        // Kill the candidate (c) so no history remains, then
        // close the head: the new head (b) takes focus — the
        // successor rule, no special case.
        state.apply(.windowDestroyed(c, wasMinimized: false))
        state.apply(.windowDestroyed(a, wasMinimized: false))
        let home = state.workspaces.space(of: b)!
        #expect(state.workspaces[home]?.focused == b)
    }

    @Test("Closing an unfocused window moves no focus")
    func unfocusedCloseKeepsFocus() {
        var state = makeState()
        state.apply(.windowDestroyed(a, wasMinimized: false))
        let home = state.workspaces.space(of: c)!
        #expect(state.workspaces[home]?.focused == c)
        #expect(state.workspaces.previousFocused == b)
    }

    @Test("A re-focus of the same window keeps the history")
    func reFocusDoesNotCollapseHistory() {
        var state = makeState()
        state.apply(.windowFocused(a))
        state.apply(.windowFocused(c))
        state.apply(.windowFocused(c))
        state.apply(.windowDestroyed(c, wasMinimized: false))
        let home = state.workspaces.space(of: a)!
        #expect(state.workspaces[home]?.focused == a)
    }

    @Test("A native-tab rekey retargets the candidate (#308)")
    func rekeyRetargetsCandidate() {
        var state = makeState()
        state.apply(.windowFocused(a))
        state.apply(.windowFocused(c))
        let a2 = WindowID(12)
        state.apply(.windowRekeyed(a, a2))
        state.apply(.windowDestroyed(c, wasMinimized: false))
        let home = state.workspaces.space(of: a2)!
        #expect(state.workspaces[home]?.focused == a2)
    }
}
