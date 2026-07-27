import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A tiled-sticky traveler holding the OS focus must be the window
/// every implicit-focused command acts on — and the one the #292
/// foreground guard vets — not the stale local `space.focused` slot
/// it can never occupy (#431/#435). Before the `focusAnchor` unify,
/// the guard resolved `focusedWindow` via `space.focused`, so a
/// CROSS-APP traveler frontmost failed the pid check and every
/// focus/swap was denied at the gate; the command bodies read the
/// same stale slot, so allowing them would have mutated the wrong
/// window. These drive `execute` with the guard wired.
@Suite("Traveler focused-command targeting", .serialized)
@MainActor
struct TravelerFocusedCommandTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-traveler-cmd-\(UUID().uuidString)"
                )
        )
    }

    private func makeWindow(
        _ id: UInt32,
        pid: pid_t,
        isSticky: Bool = false,
        appName: String = "App"
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: appName,
            title: "Title",
            stickyScope: isSticky ? .global : .none
        )
    }

    private func observe(_ core: KiwiCore, pid: pid_t) {
        guard let observer = AXApplicationObserver(pid: pid) else {
            Issue.record("could not create a self AX observer")
            return
        }
        core.eventLoop.observers[pid] = observer
    }

    /// Space "1" (active) holds two local windows owned by a
    /// DIFFERENT app pid; window 50 is a sticky traveler homed on
    /// "2" and owned by `travelerPID` (the process pid, so a real
    /// self observer exists for the guard's allow path). The active
    /// space's own `focused` is a local window, so it diverges from
    /// the anchor exactly as the cross-app trap requires.
    private func seed(_ core: KiwiCore, travelerPID: pid_t) {
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...2 {
            core.state.windows.upsert(makeWindow(id, pid: 100))
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.windows.upsert(
            makeWindow(
                50,
                pid: travelerPID,
                isSticky: true,
                appName: "Traveler"
            )
        )
        core.state.workspaces.add(WindowID(50), to: "2")
        // Local focus on "1"; system focus (lastFocused) on the
        // traveler — the divergence the anchor must resolve.
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.state.workspaces.focus(WindowID(50), in: "2")
        observe(core, pid: travelerPID)
        core.frontmostPIDProvider = { travelerPID }
    }

    /// The accessor the guard and every body now read resolves to
    /// the traveler, while the active space's own slot stays local —
    /// the precise state that used to deny the command.
    @Test("The focus anchor is the traveler, not the local slot")
    func anchorIsTraveler() {
        let core = makeCore()
        seed(core, travelerPID: getpid())
        #expect(core.focusedWindowID == WindowID(50))
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("Directional focus from a cross-app traveler is not denied")
    func focusFromTravelerAllowed() {
        let core = makeCore()
        seed(core, travelerPID: getpid())
        let response = core.execute(
            "focus",
            args: [.string("left")]
        )
        // It may legitimately dead-end ("no window left of focus"),
        // but must never be turned away by the foreground guard.
        #expect(
            response.error != "no managed window is currently focused"
        )
    }

    @Test("toggle_floating targets the traveler, not the local slot")
    func toggleFloatingHitsTraveler() {
        let core = makeCore()
        seed(core, travelerPID: getpid())
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(core.state.windows[WindowID(50)]?.isFloating == true)
        // The stale local focus was not touched.
        #expect(core.state.windows[WindowID(1)]?.isFloating == false)
    }

    @Test("toggle_sticky un-sticks the traveler, not the local slot")
    func toggleStickyHitsTraveler() {
        let core = makeCore()
        seed(core, travelerPID: getpid())
        #expect(core.execute("toggle_sticky").isSuccess)
        #expect(core.state.windows[WindowID(50)]?.isSticky == false)
        #expect(core.state.windows[WindowID(1)]?.isSticky == false)
    }

    @Test("move_to_space on a sticky traveler is refused, not misdirected")
    func moveToSpaceHitsTraveler() {
        let core = makeCore()
        seed(core, travelerPID: getpid())
        core.state.workspaces.ensureSpace("3")
        // A global sticky can't change spaces (#445): the shared
        // move guard fires on the frontmost TRAVELER (50) and
        // refuses with a pill, reported as success (a semantic
        // refusal). The traveler stays home ("2"). Crucially the
        // non-sticky local window (1) did NOT move to "3" either —
        // proof the command targeted the traveler, since targeting
        // the local slot would have relocated a NON-sticky window
        // freely.
        #expect(
            core.execute(
                "move_to_space",
                args: [.string("3")]
            ).isSuccess
        )
        #expect(core.state.workspaces.space(of: WindowID(50)) == "2")
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
    }

    @Test("stack.promote from a traveler refuses, it does not deny")
    func promoteFromTravelerRefused() {
        let core = makeCore()
        seed(core, travelerPID: getpid())
        core.state.workspaces.withSpace("1") { $0.mode = .stack }
        let before = core.state.workspaces["1"]?.windows
        let response = core.execute("stack.promote")
        // A traveler can't be reordered in a foreign space, so the
        // command is a semantic refusal (pill), reported as success —
        // never the guard denial, and never a local mutation.
        #expect(response.isSuccess)
        #expect(
            response.error != "no managed window is currently focused"
        )
        #expect(core.state.workspaces["1"]?.windows == before)
    }
}
