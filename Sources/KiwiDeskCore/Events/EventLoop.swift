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

    /// Fired when a transient filter drops a window mid-launch
    /// (#675). The pid is already queued in `pendingRetrack`;
    /// the core schedules the one-shot re-track that drains it
    /// (`scheduleTransientRetrack`).
    var onTransientDrop: @MainActor () -> Void = {}

    /// User float rules from the Lua config (`float_rules`).
    /// Assigning does NOT resync `detectedFloating`: rules
    /// change hands inside loadConfig's reset→reassign
    /// transaction, so any new assignment site outside it must
    /// follow with `reconcileAll()` or a scoped recheck (#164).
    public var floatRules = FloatRules()

    /// Global apps KiwiDesk never manages (`ignore_rules`).
    /// Bundle identifiers match case-insensitively.
    public var ignoreRules = IgnoreRules()

    /// Reads one of KiwiDesk's OWN windows' AppKit identifier —
    /// the tiling mark's lookup (#678 item 18). The production
    /// default bridges AX identity to AppKit identity through
    /// `NSApp.windows`; it is a seam because the mark is
    /// otherwise unobservable from a test, so a call site that
    /// stops consulting it — or compares the wrong constant —
    /// would silently restore the old float-everything-own
    /// behaviour with every suite green. Injected in tests
    /// (`SelfWindowExclusionTests`); never nil, since a window
    /// with no identifier answers nil on its own.
    var ownWindowIdentifier: (WindowID) -> String? = { id in
        EventLoop.ownWindow(number: Int(id.raw))?
            .identifier?.rawValue
    }

    var observers: [pid_t: any AppObserving] = [:]
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
    /// Census window ids a heal pass failed to adopt, per pid —
    /// the sweep stays quiet for exactly those ids, so a window
    /// it can never adopt (an ignored layer-0 panel) costs one
    /// reconcile total instead of one per tick, while any NEW
    /// census id still opens the gate (#675). Pruned to the
    /// live census each pass.
    var healQuiet: [pid_t: Set<WindowID>] = [:]
    /// Windows the transient filters dropped that already spent
    /// their one re-track, per pid (cleared on detach) — bounds
    /// the retry so a permanent invisible helper (#309) cannot
    /// schedule forever (#675).
    var transientRetried: [pid_t: Set<WindowID>] = [:]
    /// Pids owed a one-shot re-track for a transient drop
    /// (#675); drained by the scheduled task.
    var pendingRetrack: Set<pid_t> = []
    var workspaceTokens: [NSObjectProtocol] = []
    var screenToken: NSObjectProtocol?
    var lastActivePid: pid_t?
    public internal(set) var isRunning = false

    /// The chunked boot pass's queue, counters, per-app budget
    /// and clock seam (#801/#803) — every field is argued on
    /// `BootScanState`, in `EventLoop+BootScan.swift`.
    var bootScan = BootScanState()

    /// Log line consumer — boot diagnostics only (the startup
    /// scan summary, slow attach/reconcile spans, #672). Wired
    /// to the core sink in `KiwiCore+Bootstrap`; defaults to the
    /// syslog write like every Core seam (core-boundaries.md).
    public var onLog: @MainActor (String) -> Void = CoreLog.write

    // MARK: - Machine seams
    // Injectable per tests.md ("a test reaches the machine only
    // through a seam it injects"); production runs the live
    // defaults, tests swap fakes so `start`, attach and
    // reconcile are drivable without touching the host's apps.

    /// Creates the per-app AX observer `attach` installs.
    var makeObserver: @MainActor (pid_t) -> (any AppObserving)? =
        { AXApplicationObserver(pid: $0) }

    /// The app source the startup scan and `reconcileAll`
    /// iterate. Descriptor-shaped rather than
    /// `NSRunningApplication`-shaped so a test can fabricate an
    /// app — a real `NSRunningApplication` cannot be built for
    /// a made-up pid, which would leave every wiring below the
    /// seam unpinnable (#672 review).
    var runningApplications: () -> [RunningApp] = {
        NSWorkspace.shared.runningApplications.map(
            RunningApp.init
        )
    }

    /// The WindowServer prefilter feeding the scan's
    /// `scanWindowsAtAttach` answers (see `attach`).
    var visiblePIDs: () -> Set<pid_t> =
        AXHelper.pidsWithNormalWindows

    /// The adoption-heal gate's census (#675): on-screen layer-0
    /// window ids per owning pid, one snapshot per sweep.
    var onScreenNormalWindowIDs: () -> [pid_t: Set<WindowID>] =
        AXHelper.onScreenNormalWindowIDs

    /// AX window list of an app — `attach`'s snapshot and
    /// `reconcile`'s live list.
    var axWindows: (pid_t) -> [AXUIElement] = AXHelper.windows

    /// Activation policy for a pid a reconcile only knows by
    /// number.
    var activationPolicy: (pid_t) -> NSApplication.ActivationPolicy? = {
        NSRunningApplication(processIdentifier: $0)?
            .activationPolicy
    }

    /// The warmup taps (#360): the EUI read/write pair and the
    /// Chromium `AXManualAccessibility` write.
    var readEnhancedUI: (pid_t) -> Bool? =
        AXHelper.getEnhancedUserInterface
    var writeEnhancedUI: (pid_t, Bool) -> Void =
        AXHelper.setEnhancedUserInterface
    var writeManualAX: (pid_t, Bool) -> Void =
        AXHelper.setManualAccessibility

    /// Applies the process-global AX messaging timeout at
    /// `start` (#672) — see `AXHelper.setGlobalMessagingTimeout`
    /// for what it bounds and why.
    var applyAXMessagingTimeout: (Float) -> Void =
        AXHelper.setGlobalMessagingTimeout

    /// Whether `start()` registers the live NSWorkspace /
    /// screen-parameter observers. Default-true (production);
    /// the lifecycle suites turn it off so driving `start()`
    /// leaves no observer whose callback could re-enter the
    /// loop through live defaults mid-test. A forgotten opt-out
    /// only registers observers that are removed by `stop()` —
    /// never a missed production registration.
    var registersWorkspaceObservers = true

    /// ~1 s: comfortably above the slowest healthy responders
    /// (Electron/WebKit answer lazily in 100–300 ms,
    /// accessibility.md) yet it caps an unresponsive app at
    /// ~1 s per call instead of the ~6 s system default that
    /// turned one hung helper into a ~60 s boot (#672).
    /// `StartupAXTimeoutTests` pins the boot applying it before
    /// the first per-app AX call.
    static let axMessagingTimeoutSeconds: Float = 1.0

    public init() {}

    // Lifecycle (start/stop) lives in `EventLoop+Lifecycle.swift`.
    // Window tracking (track, recheckFloat) lives in
    // `EventLoop+Tracking.swift`; the adoption heal (#675) in
    // `EventLoop+Heal.swift`. Read-only lookups (detectionVerdict,
    // observes, element, isListed) live in
    // `EventLoop+Queries.swift`.
}
