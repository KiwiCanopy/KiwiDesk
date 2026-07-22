import AppKit
import ApplicationServices

/// Central listener for system events.
///
/// Watches app launches/terminations via `NSWorkspace` (see
/// EventLoop+Apps.swift), attaches an `AXApplicationObserver`
/// per app, and translates raw AX notifications into typed
/// `KiwiEvent`s. It keeps no layout state itself — consumers
/// apply events to the state managers.
@MainActor
public final class EventLoop {
    public var onEvent: @MainActor (KiwiEvent) -> Void = { _ in }

    /// Fired when Ghostty reports its built-in ignored quick-
    /// terminal panel as its focused window. No `.windowFocused`
    /// is emitted for the panel
    /// itself (issue #21), but the panel being active is a
    /// signal KiwiCore keeps: when the panel is dismissed the
    /// app re-reports its managed main window as focused, and
    /// that stale report must not follow focus to the main
    /// window's space (issue #244). Carries the app's pid.
    ///
    /// Relies on AX reporting the panel *element* as focused at
    /// least once while it is up (the untracked-window branch in
    /// EventLoop+Notifications / EventLoop+Apps): that is when
    /// the pid is flagged. Confirmed for Ghostty's quick
    /// terminal by manual pass; a future ignored-panel app that
    /// only ever re-reports its main window would not flag, and
    /// the dismiss follow would return (the pre-fix behavior).
    public var onIgnoredPanelFocus: @MainActor (pid_t) -> Void = { _ in
    }

    /// User float rules from the Lua config (`float_rules`).
    /// Assigning does NOT resync `detectedFloating`: rules
    /// change hands inside loadConfig's reset→reassign
    /// transaction, so any new assignment site outside it must
    /// follow with `reconcileAll()` or a scoped recheck (#164).
    public var floatRules = FloatRules()

    /// Global apps KiwiDesk never manages (`ignore_rules`).
    /// Bundle identifiers match case-insensitively.
    public var ignoreRules = IgnoreRules()

    var observers: [pid_t: AXApplicationObserver] = [:]
    var elements: [pid_t: [WindowID: AXUIElement]] = [:]
    /// AXEnhancedUserInterface state observed before this loop
    /// changed it. An ignore transition or stop restores that
    /// exact value instead of assuming KiwiDesk owned `true`.
    var enhancedUIBaselines: [pid_t: Bool] = [:]
    /// Apps sent `AXManualAccessibility` — the Chromium warm-up used
    /// when an app never answers the EUI read (#360). Set-once per
    /// process: unlike the EUI baseline, a Chromium app answers that
    /// read permanently with nil, so without this the warm-up would
    /// re-fire a blocking AX write on every reconcile. Deliberately
    /// not restored on detach — unlike EUI, an eager AX tree is what a
    /// managed app wants and Chromium's does not tear down, so re-poking
    /// it costs more than it buys; only the pid is cleared so a
    /// re-attach re-applies the warm-up.
    var manualAXApplied: Set<pid_t> = []
    /// Last float-detection verdict per tracked window, so
    /// reconcile can re-check and emit only actual changes
    /// (manual make_floating overrides stay untouched).
    var detectedFloating: [WindowID: Bool] = [:]
    /// Last native-fullscreen verdict per tracked window, so the
    /// reconcile recheck emits `.windowFullscreenChanged` only on
    /// an actual transition (mirrors `detectedFloating`).
    var detectedFullscreen: [WindowID: Bool] = [:]
    /// Tracked windows whose CGWindow layer read as ignored
    /// once; untracked only if the reading persists (layers
    /// flicker during fullscreen transitions).
    var ignorePending: Set<WindowID> = []
    /// Last-known on-screen frame of every tracked window — the key
    /// `TabReconciler` matches a vanished window against an appearing
    /// one on a native-tab switch (#308). Kept for all windows (not
    /// just carriers) so the 1↔2 tab boundary — where the vanishing
    /// or appearing window has no tab group yet — still matches by
    /// frame. Set at track, refreshed on move/resize/reconcile,
    /// moved on re-key, cleared on destroy/detach/stop.
    var trackedFrames: [WindowID: CGRect] = [:]
    /// Tracked windows that carry (or last carried) an `AXTabGroup`.
    /// A re-key needs a tab group on only one side, so this preserves
    /// the "was a carrier" fact for a window that vanishes after a
    /// switch even though its element is gone (#308).
    var tabCarriers: Set<WindowID> = []
    /// When the user last switched native Spaces. Tab coalescing is
    /// suppressed for a short window afterward: a space switch shows
    /// the departed space's windows as vanished and the arrived
    /// space's as appeared, and a *targeted* reconcile (focus-changed
    /// / app-activation) racing the bulk `reconcileAll` could pair a
    /// tab carrier across spaces (identical tiled frames) into a bogus
    /// re-key. `reconcileAll` itself passes `coalesceTabs: false`;
    /// this closes the stray-targeted-reconcile residual (#308 review).
    var lastNativeSpaceChange: Date = .distantPast
    /// Grace window after a native-Space change during which no
    /// reconcile coalesces tabs. A genuine tab switch within it
    /// falls back to destroy + create (self-healing), which is rare.
    static let spaceSwitchCoalesceGrace: TimeInterval = 0.75
    var workspaceTokens: [NSObjectProtocol] = []
    var screenToken: NSObjectProtocol?
    var lastActivePid: pid_t?
    public private(set) var isRunning = false

    public init() {}

    // MARK: - Lifecycle

    /// Starts observing. Requires Accessibility permission.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        registerWorkspaceObservers()
        for app in NSWorkspace.shared.runningApplications {
            attach(app: app)
        }
        publishDisplays()
    }

    /// Stops observing and forgets all tracked windows.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        let center = NSWorkspace.shared.notificationCenter
        for token in workspaceTokens {
            center.removeObserver(token)
        }
        workspaceTokens = []
        if let screenToken {
            NotificationCenter.default
                .removeObserver(screenToken)
        }
        screenToken = nil
        for observer in observers.values {
            observer.invalidate()
        }
        for (pid, baseline) in enhancedUIBaselines
        where !baseline {
            AXHelper.setEnhancedUserInterface(
                pid: pid,
                enabled: false
            )
        }
        observers = [:]
        elements = [:]
        enhancedUIBaselines = [:]
        manualAXApplied = []
        detectedFloating = [:]
        detectedFullscreen = [:]
        ignorePending = []
        trackedFrames = [:]
        tabCarriers = []
    }

    // Read-only lookups (detectionVerdict, observes, element,
    // isListed) live in `EventLoop+Queries.swift`.

    // MARK: - Window tracking

    func track(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef,
        displayBounds: [CGRect]? = nil
    ) {
        let role = AXHelper.role(of: element)
        guard role == kAXWindowRole,
            !AXHelper.isMinimized(element),
            var window = AXHelper.snapshot(
                element: element,
                pid: pid,
                app: app
            )
        else { return }
        guard elements[pid]?[window.id] == nil else { return }
        let subrole = AXHelper.subrole(of: element)
        // One WindowServer round trip feeds every
        // classification below (layer, alpha, bounds).
        let server = FloatDetection.serverSnapshot(
            of: window.id
        )
        let layer = server.layer
        let displays =
            layer == nil || layer == 0
            ? []
            : displayBounds
                ?? FloatDetection.activeDisplayBounds()
        guard
            !FloatDetection.isUnbackedAuxiliary(
                role: role,
                subrole: subrole,
                layer: layer
            )
        else { return }
        // #309: an invisible raised-layer helper (alpha-0 or
        // fully off-screen lifecycle keepalive) never enters
        // state — tracked, it would earn a Space slot and an
        // App Bar item and read as an open app. A genuine
        // overlay caught mid fade-in is re-tracked by a later
        // reconcile pass once visible.
        guard
            !FloatDetection.isInvisibleHelper(
                layer: layer,
                alpha: server.alpha,
                bounds: server.bounds,
                displays: displays
            )
        else { return }
        // Some panels must never be managed at all — merely
        // floating them still pins them to a space (issue #21).
        guard
            !shouldIgnore(
                element,
                pid: pid,
                app: app,
                layer: layer ?? 0
            )
        else {
            return
        }
        window.isFloating =
            shouldForceFloat(pid: pid)
            || FloatDetection.shouldFloat(
                element: element,
                bundleID: app.bundleID,
                layer: layer,
                rules: floatRules
            )
        // A transient overlay floats for a *structural* reason
        // (third-party accessory app, panel subrole, or raised
        // layer), never just because a float rule matched — so a
        // user-floated standard window keeps its ring while a
        // launcher does not (#300). Our own Settings window is
        // exempt (#315, see `classifiesAsOverlay`).
        window.isTransientOverlay =
            classifiesAsOverlay(pid: pid)
            || FloatDetection.shouldFloat(
                role: role,
                subrole: subrole,
                layer: layer ?? 0
            )
        // Native fullscreen suppresses the focus ring (a ring
        // around a display-filling window shows only at the
        // corners); snapshot it here, refresh on reconcile.
        window.isFullscreen = AXHelper.isFullscreen(element)
        detectedFloating[window.id] = window.isFloating
        detectedFullscreen[window.id] = window.isFullscreen
        elements[pid, default: [:]][window.id] = element
        observers[pid]?.observe(window: element)
        // Remember every window's frame, and which windows carry a
        // native tab group, so a later switch (this window vanishing
        // as a sibling appears at the same frame) coalesces into a
        // re-key instead of a destroy + create (#308).
        trackedFrames[window.id] = window.frame
        if AXHelper.hasNativeTabs(element) {
            tabCarriers.insert(window.id)
        }
        onEvent(.windowCreated(window))
    }

    /// Re-runs float detection on an already-tracked window.
    /// A window scanned mid-launch or mid-animation can report
    /// a wrong subrole once (Ghostty's quick terminal during
    /// the startup scan) and would otherwise stay misclassified
    /// until it closes. Only a changed detection verdict emits,
    /// so manual make_floating overrides survive reconciles.
    // Internal (not private): also called by `handle` in
    // EventLoop+Notifications.swift.
    func recheckFloat(
        _ element: AXUIElement,
        id: WindowID,
        pid: pid_t,
        app: AppRef
    ) {
        recheckFullscreen(element, id: id)
        let floating =
            shouldForceFloat(pid: pid)
            || FloatDetection.shouldFloat(
                element: element,
                bundleID: app.bundleID,
                rules: floatRules
            )
        guard detectedFloating[id] != floating else { return }
        detectedFloating[id] = floating
        onEvent(.windowFloatChanged(id, isFloating: floating))
    }

    /// Re-reads native-fullscreen state on reconcile so a
    /// green-button transition (no destroy/create pair) flips
    /// the snapshot flag and the focus ring follows. Change-only,
    /// like the float recheck above.
    private func recheckFullscreen(
        _ element: AXUIElement,
        id: WindowID
    ) {
        let fullscreen = AXHelper.isFullscreen(element)
        guard detectedFullscreen[id] != fullscreen else { return }
        detectedFullscreen[id] = fullscreen
        onEvent(
            .windowFullscreenChanged(
                id,
                isFullscreen: fullscreen
            )
        )
    }

}
