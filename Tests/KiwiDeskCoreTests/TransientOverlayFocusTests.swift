import Foundation
import Testing

@testable import KiwiDeskCore

/// #671: a transient overlay — a context menu, a panel, any
/// window that floats for a *structural* reason (#300) — must
/// never occupy a space's `focused` slot. Every fresh window used
/// to take it with no classification signal consulted, so a popup
/// became `space.focused` on creation and its dismissal read as a
/// `focusLost`: the fallback handoff issued a real AX raise plus
/// a mouse warp (right-clicking in Telegram moved the pointer).
///
/// The four seams that write the slot are pinned here. Each is
/// paired with its grant arm, keyed on a window that FLOATS but
/// is not an overlay — the denial keys on the structural flag,
/// never on floating-ness, exactly as the ring does.
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

    // MARK: - The predicate

    @Test("Only a structural overlay is barred from the slot")
    func predicateKeysOnTheStructuralFlag() {
        let core = makeCore()
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(
            .windowCreated(window(2, floating: true))
        )
        core.state.apply(
            .windowCreated(
                window(3, floating: true, overlay: true)
            )
        )
        #expect(core.state.mayHoldSpaceFocus(WindowID(1)))
        #expect(core.state.mayHoldSpaceFocus(WindowID(2)))
        #expect(!core.state.mayHoldSpaceFocus(WindowID(3)))
    }

    // MARK: - Seam 1: the create fold

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

    /// The grant arm: a window the user floated through a
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

    /// The flag clears the moment detection heals the window back
    /// to tiled (`setFloating`, #300), so the create fold must
    /// ask STATE and not the incoming snapshot.
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

    // MARK: - Seam 2: the focus report

    /// The route that used to survive the create-fold gate: macOS
    /// really does focus the popup, and reporting it moved the
    /// slot. Recording it stranded every consumer of the slot on
    /// a window that then vanished with no reconciling event.
    @Test("An OS focus report on an overlay moves nothing")
    func focusReportOnOverlayIsNotRecorded() {
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
            core.state.workspaces["1"]?.focused == WindowID(1)
        )
    }

    @Test("A focus report on a plain float is recorded")
    func focusReportOnPlainFloatIsRecorded() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(1)))
        core.handle(.windowFocused(WindowID(1)))
        core.handle(.windowCreated(window(2, floating: true)))
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(2)
        )
    }

    /// The consequence the two seams above buy: an overlay can
    /// never be the window a removal reports as focus-losing, so
    /// the wiring's fallback raise + mouse warp cannot fire for
    /// one. (`focusLost` is the flag `KiwiCore+Events` gates that
    /// raise on; its `isListed` companion needs live AX, so the
    /// raise itself is not reachable from here.)
    @Test("An overlay's removal reports no focus loss")
    func overlayRemovalReportsNoFocusLoss() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(
            .windowCreated(
                window(2, floating: true, overlay: true)
            )
        )
        core.state.apply(.windowFocused(WindowID(2)))
        let effects = core.state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        #expect(effects.removedWindow?.focusLost == false)
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(1)
        )
    }

    @Test("A plain float's removal still reports focus loss")
    func plainFloatRemovalReportsFocusLoss() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(
            .windowCreated(window(2, floating: true))
        )
        core.state.apply(.windowFocused(WindowID(2)))
        let effects = core.state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        #expect(effects.removedWindow?.focusLost == true)
    }

    // MARK: - Seams 3 & 4: the "take the first member" fallbacks

    @Test("The startup seed skips an overlay-only space")
    func startupSeedSkipsOverlay() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(
            .windowCreated(
                window(1, floating: true, overlay: true)
            )
        )
        core.seedStartupFocus(frontmost: nil)
        #expect(core.state.workspaces["1"]?.focused == nil)
    }

    @Test("The startup seed still takes a plain float")
    func startupSeedTakesPlainFloat() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(
            .windowCreated(window(1, floating: true))
        )
        core.seedStartupFocus(frontmost: nil)
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(1)
        )
    }

    /// A frontmost probe that lands on a launcher must not seed
    /// the slot with it either — same wrong answer, other route.
    @Test("The startup seed ignores an overlay frontmost")
    func startupSeedIgnoresOverlayFrontmost() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(
            .windowCreated(
                window(2, floating: true, overlay: true)
            )
        )
        core.seedStartupFocus(frontmost: WindowID(2))
        #expect(
            core.state.workspaces["1"]?.focused == WindowID(1)
        )
    }

    @Test("The space-switch target skips an overlay-only space")
    func spaceSwitchTargetSkipsOverlay() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(
            .windowCreated(
                window(1, floating: true, overlay: true)
            )
        )
        #expect(core.resolveSpaceSwitchFocusTarget() == nil)
        #expect(core.state.workspaces["1"]?.focused == nil)
    }

    @Test("The space-switch target still takes a plain float")
    func spaceSwitchTargetTakesPlainFloat() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.apply(
            .windowCreated(window(1, floating: true))
        )
        #expect(
            core.resolveSpaceSwitchFocusTarget() == WindowID(1)
        )
    }
}
