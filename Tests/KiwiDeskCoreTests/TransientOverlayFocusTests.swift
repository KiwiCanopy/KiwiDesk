import Foundation
import Testing

@testable import KiwiDeskCore

/// #671: a transient overlay — a context menu, a panel, any
/// window that floats for a *structural* reason (#300) — must be
/// inert around focus. `applyWindowCreated` used to grant every
/// fresh window the space's focus with no classification signal
/// consulted, which made a popup's dismissal a `focusLost` and
/// sent a real AX raise plus a mouse warp onto the fallback
/// (right-clicking in Telegram moved the pointer).
@MainActor
@Suite("Transient-overlay focus inertness (#671)", .serialized)
struct TransientOverlayFocusTests {

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-overlay-\(UUID().uuidString)"
                )
        )
    }

    private func window(
        _ raw: UInt32,
        floating: Bool = false,
        overlay: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(raw),
            pid: pid_t(raw),
            appName: "App\(raw)",
            appBundleID: "app.test.\(raw)",
            title: "W\(raw)",
            isFloating: floating,
            isTransientOverlay: overlay
        )
    }

    // MARK: - The create-time grant

    @Test("An overlay spawn leaves the space's focus alone")
    func overlayDoesNotTakeFocus() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(1)))
        core.handle(.windowFocused(WindowID(1)))
        core.handle(
            .windowCreated(
                window(2, floating: true, overlay: true)
            )
        )
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(1)
        )
        #expect(
            core.state.workspaces.lastFocused == WindowID(1)
        )
    }

    /// Scope guard: the signal is the *structural* overlay flag,
    /// not floating-ness. A window the user floated through a
    /// `float_rules` entry is an ordinary window and still takes
    /// focus when it spawns.
    @Test("A plain floating spawn still takes focus")
    func plainFloatStillTakesFocus() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(1)))
        core.handle(.windowFocused(WindowID(1)))
        core.handle(.windowCreated(window(2, floating: true)))
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(2)
        )
    }

    /// The overlay flag clears the moment detection heals the
    /// window back to tiled (`setFloating`, #300) — so the grant
    /// must read state after the fold, never the incoming
    /// snapshot. A remembered-tiled override does exactly that
    /// inside `applyWindowCreated`.
    @Test("A healed overlay takes focus like any window")
    func healedOverlayTakesFocus() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(1)))
        core.handle(.windowFocused(WindowID(1)))
        // A remembered make_tiled for that window's identity:
        // the fold's `restoreFloatOverride` untiles it, and
        // `setFloating(_, false)` drops the overlay flag with it.
        let overlay = window(2, floating: true, overlay: true)
        core.state.rememberedFloating[
            StateCoordinator.WindowIdentity(of: overlay)
        ] = false
        core.handle(.windowCreated(overlay))
        #expect(
            core.state.windows[WindowID(2)]?
                .isTransientOverlay == false
        )
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(2)
        )
    }

    // MARK: - The close-side handoff

    /// The whole handoff decision, reachable without live AX:
    /// the wiring's own gate also needs `eventLoop.isListed`,
    /// which only answers true for a window AX still lists.
    @Test("An overlay's removal owes no focus handoff")
    func overlayRemovalOwesNoHandoff() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(
            .windowCreated(
                window(2, floating: true, overlay: true)
            )
        )
        // The OS reported the popup focused — the one route by
        // which an overlay still reaches `space.focused`.
        core.state.apply(.windowFocused(WindowID(2)))
        let effects = core.state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        #expect(effects.removedWindow?.focusLost == true)
        #expect(
            effects.removedWindow?.wasTransientOverlay == true
        )
        #expect(effects.removedWindow?.handsOffFocus == false)
    }

    /// The grant arm of the same predicate: an ordinary focused
    /// window closing still hands its focus off.
    @Test("An ordinary window's removal still hands focus off")
    func ordinaryRemovalHandsFocusOff() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(.windowCreated(window(2)))
        core.state.apply(.windowFocused(WindowID(2)))
        let effects = core.state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        #expect(effects.removedWindow?.handsOffFocus == true)
    }

    // MARK: - The pending focus-follow

    @Test("An overlay spawn keeps a pending focus follow")
    func overlaySpawnKeepsPendingFollow() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(1)))
        core.deferred.schedule(
            .focusFollow,
            after: .seconds(30)
        ) {}
        core.handle(
            .windowCreated(
                window(2, floating: true, overlay: true)
            )
        )
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }

    @Test("An ordinary spawn still cancels a pending follow")
    func ordinarySpawnCancelsPendingFollow() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(1)))
        core.deferred.schedule(
            .focusFollow,
            after: .seconds(30)
        ) {}
        core.handle(.windowCreated(window(2)))
        #expect(core.deferred.task(for: .focusFollow) == nil)
    }
}
