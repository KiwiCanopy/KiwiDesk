import Foundation
import Testing

@testable import KiwiDeskCore

/// #671: the create fold granted every fresh window its space's
/// focus with no classification signal consulted. A popup that
/// surfaces as an AX window — a Telegram context menu — therefore
/// became `space.focused`, so its dismissal read as a `focusLost`
/// and the fallback handoff fired a real AX raise plus a mouse
/// warp off what the user had just clicked.
///
/// The grant is what these pin, and only the grant. A window in
/// this class that macOS genuinely focuses still reaches the slot
/// through the focus report — which is what a layer-0 dialog
/// (also `isTransientOverlay`) needs, and what #300 settled by
/// keeping the correction at draw time.
@MainActor
@Suite("Transient-overlay focus grant (#671)", .serialized)
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

    /// The consequence: with the grant denied, dismissing the
    /// popup is not a `focusLost`, so `KiwiCore+Events`' fallback
    /// raise + pointer warp never fires for it. (That wiring also
    /// gates on `eventLoop.isListed`, which needs live AX, so the
    /// raise itself is not reachable from here — this is the
    /// state half, and it is the half #671 broke.)
    @Test("Dismissing the popup reports no focus loss")
    func overlayDismissalReportsNoFocusLoss() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(.windowFocused(WindowID(1)))
        core.state.apply(
            .windowCreated(
                window(2, floating: true, overlay: true)
            )
        )
        let effects = core.state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        #expect(effects.removedWindow?.focusLost == false)
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(1)
        )
    }

    /// The grant arm, and the scope of the signal: the denial
    /// keys on the STRUCTURAL overlay flag, never on
    /// floating-ness. A window the user floated through a
    /// `float_rules` entry is ordinary and still takes focus.
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

    @Test("An ordinary spawn still takes focus")
    func ordinarySpawnStillTakesFocus() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(1)))
        core.handle(.windowFocused(WindowID(1)))
        core.handle(.windowCreated(window(2)))
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(2)
        )
    }

    /// Only the grant is denied. macOS focusing the window for
    /// real still moves the slot — the route a long-lived member
    /// of this class (a layer-0 dialog or panel, #300) depends
    /// on, and the reason this fix stops at the grant.
    @Test("An OS focus report still reaches an overlay")
    func focusReportStillMovesTheSlot() {
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
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(2)
        )
    }

    /// The flag clears the moment detection heals the window back
    /// to tiled (`setFloating`, #300), so the fold must ask STATE
    /// — after `upsert` and `restoreFloatOverride` — and not the
    /// incoming snapshot.
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

    /// The #636 arm the denial must not swallow: a space whose
    /// members all left with a native switch has `focused == nil`,
    /// and the first ORDINARY returner still seeds it — the
    /// settle fallback needs a target even when no focus report
    /// ever arrives.
    @Test("A returning window still seeds an empty space")
    func returningWindowStillSeedsEmptyFocus() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(1)))
        core.handle(.nativeSpaceChanged)
        core.handle(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        core.handle(.nativeSpaceChanged)
        core.handle(.windowCreated(window(1)))
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(1)
        )
    }
}
