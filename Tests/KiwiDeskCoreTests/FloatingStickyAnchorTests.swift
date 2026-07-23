import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A FLOATING sticky traveler holding the OS focus must be the
/// window implicit-focused verbs act on (#416). It is never in
/// `effectiveTiledMembers`, so before the anchor learned the
/// render-space test it resolved past the traveler to the stale
/// local `space.focused`: with the same app owning a local
/// window the #292 pid guard passed and `toggle_sticky` — the
/// verb pressed while looking at a sticky — silently mutated
/// the wrong window.
@Suite("Floating-sticky focus anchor", .serialized)
@MainActor
struct FloatingStickyAnchorTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-float-sticky-\(UUID().uuidString)"
                )
        )
    }

    private func makeWindow(
        _ id: UInt32,
        pid: pid_t,
        isSticky: Bool = false,
        isFloating: Bool = false,
        appName: String = "App"
    ) -> ManagedWindow {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: appName,
            title: "Title",
            stickyScope: isSticky ? .global : .none
        )
        window.isFloating = isFloating
        return window
    }

    private func observe(_ core: KiwiCore, pid: pid_t) {
        guard let observer = AXApplicationObserver(pid: pid) else {
            Issue.record("could not create a self AX observer")
            return
        }
        core.eventLoop.observers[pid] = observer
    }

    /// Space "1" (active) holds two local windows owned by
    /// `localPID`; window 50 is a FLOATING global sticky homed
    /// on "2", owned by `travelerPID`, and `lastFocused` — the
    /// user clicked the sticky rendered over the active space.
    private func seed(
        _ core: KiwiCore,
        localPID: pid_t,
        travelerPID: pid_t
    ) {
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...2 {
            core.state.windows.upsert(
                makeWindow(id, pid: localPID)
            )
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.windows.upsert(
            makeWindow(
                50,
                pid: travelerPID,
                isSticky: true,
                isFloating: true,
                appName: "Traveler"
            )
        )
        core.state.workspaces.add(WindowID(50), to: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.state.workspaces.focus(WindowID(50), in: "2")
        observe(core, pid: travelerPID)
        core.frontmostPIDProvider = { travelerPID }
    }

    @Test("The anchor is the floating sticky, not the local slot")
    func anchorIsFloatingSticky() {
        let core = makeCore()
        seed(core, localPID: 100, travelerPID: getpid())
        #expect(core.focusedWindowID == WindowID(50))
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("An inactive space still yields its own focus")
    func inactiveSpaceKeepsLocalFocus() {
        let core = makeCore()
        seed(core, localPID: 100, travelerPID: getpid())
        core.state.workspaces.ensureSpace("3")
        // The sticky renders on the ACTIVE space ("1"), so it
        // must not anchor a space it is not rendered on.
        if let three = core.state.workspaces[SpaceID("3")] {
            #expect(core.state.focusAnchor(of: three) == nil)
        } else {
            Issue.record("space 3 missing")
        }
    }

    /// THE #416 repro: same app owns the sticky and a local
    /// window, so the pid-granular guard passes either way —
    /// the verb must hit the sticky under the user's eyes.
    @Test("Same-app toggle_sticky un-sticks the frontmost sticky")
    func sameAppToggleStickyHitsTraveler() {
        let core = makeCore()
        let pid = getpid()
        seed(core, localPID: pid, travelerPID: pid)
        #expect(core.execute("toggle_sticky").isSuccess)
        #expect(
            core.state.windows[WindowID(50)]?.isSticky == false
        )
        // The stale local slot was not made sticky.
        #expect(
            core.state.windows[WindowID(1)]?.isSticky == false
        )
    }

    @Test("Cross-app toggle_floating is allowed and hits the sticky")
    func crossAppToggleFloatingHitsTraveler() {
        let core = makeCore()
        seed(core, localPID: 100, travelerPID: getpid())
        // Un-floats the sticky (it was floating); the point is
        // the guard no longer fails closed on the pid mismatch
        // against the stale local slot.
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(
            core.state.windows[WindowID(50)]?.isFloating == false
        )
        #expect(
            core.state.windows[WindowID(1)]?.isFloating == false
        )
    }

    @Test("move_to_space on the floating sticky is refused")
    func moveToSpaceRefused() {
        let core = makeCore()
        seed(core, localPID: 100, travelerPID: getpid())
        core.state.workspaces.ensureSpace("3")
        // The #445 sticky move guard fires on the traveler; a
        // local-slot mis-target would have moved window 1 freely.
        #expect(
            core.execute(
                "move_to_space",
                args: [.string("3")]
            ).isSuccess
        )
        #expect(
            core.state.workspaces.space(of: WindowID(50)) == "2"
        )
        #expect(
            core.state.workspaces.space(of: WindowID(1)) == "1"
        )
    }

    @Test("resize is not denied while the sticky is frontmost")
    func resizeNotDenied() {
        let core = makeCore()
        seed(core, localPID: 100, travelerPID: getpid())
        // resize keeps resolving against the local slot (the
        // id-keyed-weights orphan rule) — but the guard vets
        // the anchor, so it must not fail closed here.
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(50)]
        )
        #expect(
            response.error
                != "no managed window is currently focused"
        )
    }
}
