import AppKit
import Foundation

/// The application core: owns state, event loop, tiler, Lua,
/// and the event bus, and wires them together. The GUI layer
/// (AppDelegate) only handles permissions and windows.
@MainActor
public final class KiwiCore {
    public let eventLoop = EventLoop()
    public internal(set) var state = StateCoordinator()
    public let tiler = TilingEngine()
    public let sleepWake = SleepWakeManager()
    public let bus = EventBus()
    public let keys: KeybindingManager
    public let drag = DragCoordinator()
    public let dragOverlay = DragOverlay()
    public let appBars = AppBarManager()
    public let spaceBars = SpaceBarManager()
    /// Space Bar drag-drop gesture state (#372).
    let spaceBarDrop = SpaceBarDropCoordinator()
    /// Live cross-display make-room gesture state (#504).
    let dragCrossing = DragCrossingCoordinator()
    /// Glyph-vs-image icon decisions for bar items (#294),
    /// shared by the App Bar, the Space Bar (#293) and the
    /// shortcuts panel.
    public let appFont = AppFontResolver()
    /// Focus-window border overlays (#278), one ring per bordered
    /// window. Driven by `updateBorders()` inside `retile()`.
    public let borders = BorderManager()
    /// On-window sticky marks (#414): a border sibling,
    /// driven by `updateStickyMarks()` inside `retile()`.
    public let stickyMarks = StickyMarkManager()
    let strandDetector = StrandDetector()
    public let mouse = MouseTracker()
    public let profiles: ProfileManager
    public let crash: CrashRecovery
    public internal(set) var lua: LuaInterpreter?
    public let exec = ExecLauncher()

    /// Effective structured keybinding sources currently
    /// installed in `keys`. Kept so a recorder-only live edit
    /// can capture an in-memory rollback point without reading
    /// gui.json or a profile again (#123 review).
    var appliedStructuredModes: [KeyMode]?
    /// Changes whenever `loadConfig()` replaces the Lua VM and
    /// hotkey table. Recorder snapshots are valid only within
    /// the generation that captured them.
    var keybindingRuntimeGeneration: UInt64 = 0

    /// Global window-rule bases captured from the active config
    /// owner before any profile sparse diff is applied. Required
    /// for Lua-managed profiles: live state holds the effective
    /// rules and therefore cannot serve as the next profile's base.
    var globalAppRuleBase: [String: SpaceID] = [:]
    var globalFloatRuleBase: [String] = []
    var globalIgnoreRuleBase: [String] = []
    /// `loadConfig` installs several candidate rule states before
    /// the active native-Space binding is known. Suppress their AX
    /// reconciles and run one pass after the final profile wins.
    var defersWindowRuleReconcile = false

    /// A stack z-order restore is waiting for the current
    /// animations to settle (see restoreStackZOrder).
    var pendingZOrderRestore = false

    /// A command reordered windows but its paired retile is the
    /// dispatcher's own trailing `retile(force:)`, not one it
    /// issued itself (#153) — `layoutCommand` arms the z-order
    /// restore *after* that retile so it can't fire mid-retile
    /// from pre-retile frames. Set via
    /// `requestZOrderRestoreAfterDispatch`; reset each dispatch.
    var deferredCommandZOrderRestore = false

    /// A scrolling focus move whose AX raise is waiting for
    /// the pan to settle (#143) — a single slot, so rapid
    /// focus commands supersede each other and only the last
    /// target raises (see runPendingFocusRaise).
    var pendingFocusRaise: WindowID?

    /// Window ids KiwiDesk's own AX raises issued but whose focus
    /// echoes have not yet landed (#152). A matching echo is
    /// self-inflicted, not a user action: it must not supersede a
    /// newer focus nor snap state focus back. A *set*, not one
    /// slot, because forward focus raises immediately (#158) while
    /// a backward raise may still be unechoed — two self-raises
    /// can be outstanding at once. An id is removed on its own
    /// echo, and when its window is destroyed (WindowIDs can be
    /// reused). See `handleWindowFocused` in
    /// `KiwiCore+FocusEvents.swift`.
    var outstandingSelfRaises: Set<WindowID> = []

    /// When each self-raise was issued — the recency bound for
    /// the same-app activation re-report distrust (#465 QA):
    /// only a raise younger than `selfRaiseSiblingWindow` makes
    /// a sibling's hidden-space focus report suspect. Purely
    /// age-compared (pruned on write, never consumed), so a
    /// raise that never echoes cannot poison the app's hidden
    /// windows forever — the `zOrderRaiseEchoWindow` lesson.
    var selfRaiseStamps: [WindowID: Date] = [:]

    /// Sized like `zOrderRaiseEchoWindow`, and for the same
    /// reason: Electron/WebKit apps answer AX lazily (100–300
    /// ms), so their activation re-report can trail our raise
    /// by several hundred ms; beyond ~1 s a same-app report is
    /// a user action, not our raise's echo.
    static let selfRaiseSiblingWindow: TimeInterval = 1.0

    /// Last left press, AX coords (#496): the click
    /// discriminator for the cross-display sibling distrust —
    /// see `recentClickInside`. Stamped in `KiwiCore+Lifecycle`.
    var lastLeftClick: (at: Date, point: CGPoint)?

    /// Windows we raised purely for z-order, stamped with the raise
    /// time — floats promoted above the tiled plane (#418) AND the
    /// overflow-pile members a cascade restore re-raises (#425). A
    /// raise (`kAXRaiseAction`) couples with app activation, so it
    /// emits a focus echo carrying no self-raise provenance (#152);
    /// an echo on a stamped member within `zOrderRaiseEchoWindow`
    /// whose id differs from the focus the user actually reached is
    /// that echo — reverted, not honored, so the ring stays on the
    /// real focus while the raise keeps its z-order. The stamp bounds
    /// the ambiguity: a *deliberate* focus of such a window outside
    /// the window is never mistaken for the echo (a bare set poisoned
    /// a lingering entry forever when a raise emitted no echo).
    /// Stamped per sequence (restamped, pruned by age), consumed on
    /// echo, cleaned on destroy/rekey.
    var zOrderRaiseEchoes: [WindowID: Date] = [:]

    /// Bumped per z-order raise sequence (float raise or pile
    /// restore) so a stale sequence's focus handoff cannot steal
    /// focus back after a newer focus has superseded it (the
    /// `runPendingFocusRaise` staleness pattern). The `zOrderRaise
    /// Echoes` revert keeps focus on the real target, which is what
    /// makes the live-focus half of the guard safe to check.
    var zOrderRaiseGeneration = 0

    /// How long after a z-order raise its focus echo may still arrive
    /// and be reverted (#418/#425). Sized to the slowest AX
    /// responders — Electron/WebKit answer focus queries in
    /// ~100-300 ms (§5) — with ~3x margin, at the cost of a
    /// deliberate focus of a raised window within the window being
    /// eaten once (strictly better than the old permanent
    /// poisoning). Tunable.
    static let zOrderRaiseEchoWindow: TimeInterval = 1.0

    /// Resolves the OS foreground app's pid for the focused-command
    /// preflight (#292). `nil` disables the guard — the default, so
    /// unit tests exercising focused commands directly are
    /// unaffected; `start()` installs the real
    /// `NSWorkspace.frontmostApplication` reader, and guard tests
    /// inject a stub. When wired, a `nil` *return* means foreground
    /// ownership is unknown, which fails the command closed.
    var frontmostPIDProvider: (@MainActor () -> pid_t?)?

    /// Hands key focus to the desktop (Finder) when a move without
    /// follow empties the focused display's space (#446). macOS has
    /// no native "focus the empty desktop", so the moved — now
    /// stashed offscreen — window would otherwise keep key focus.
    /// Injectable and `nil` by default so unit tests observe the
    /// yield without a live Finder; `start()` installs the real
    /// activation.
    var desktopFocusYield: (@MainActor () -> Void)?

    /// Pids of apps currently showing a focused ignored panel
    /// (Ghostty's quick terminal). Set when the event loop
    /// filters the panel's own focus report (#21); consumed by
    /// the next managed-window focus of the same app — the
    /// panel's dismiss transition, where the app re-reports its
    /// main window (possibly on another space) as focused. That
    /// report is spurious and must not follow focus (#244). Only
    /// apps with an ignore rule ever land here, so at most one
    /// pid is present in practice.
    var ignoredPanelActive: Set<pid_t> = []

    /// Z-order restores whose raise sequence has not re-asserted
    /// focus yet (#186). The pile raises steal focus window by
    /// window and those echoes are not in `outstandingSelfRaises`
    /// (#152's provenance gap), so mouse-follows-focus holds its
    /// warp while any restore is in flight. A count, not a flag:
    /// back-to-back restores overlap on the serial raise queue.
    /// Warp-scoped by design (`mouseWarpEligible` is the only
    /// reader); a second consumer is the signal to close #152's
    /// gap properly — pile-raise provenance — not to extend this.
    var zOrderRestoresInFlight = 0

    /// The deferred one-shot settle tasks (focus follow, startup
    /// sweep, space settles), keyed so `stop()` cancels them all
    /// without a hand-kept list (#49). Bodies live at the
    /// `schedule*` call sites.
    let deferred = DeferredTasks()

    /// Windows just moved without follow, whose focus re-reports
    /// must not space-follow (#482/#483) — see the type doc.
    let moveLatch = MoveIntentLatch()

    /// Native desktop we are currently on (Mission Control
    /// number), and the virtual space each desktop showed
    /// last, restored when the user returns to it.
    var lastNativeSpace: Int?
    var virtualSpaceMemory: [Int: SpaceID] = [:]
    /// When the last native desktop switch happened; focus
    /// events during the transition must not change spaces.
    var lastNativeSwitch: Date = .distantPast

    /// The live arrangement's space→monitor fingerprint pins,
    /// adopted from the active profile's matching monitor set
    /// and edited by the GUI Canvas (#36). Internal: the GUI
    /// reads placement via `loadGuiConfig` and writes it via
    /// `applyProfileScopedState`, never directly.
    var spacePins: [SpaceID: String] = [:]
    /// Spaces assigned the *Main* role — they follow whatever
    /// display is currently main (#36).
    var mainSpaces: Set<SpaceID> = []
    /// The live arrangement's explicit rehome target (#68) —
    /// adopted from the active profile, edited by the GUI, and
    /// captured back on save. nil falls back to the space
    /// order's first survivor on a profile-switch reconcile.
    var fallbackSpace: SpaceID?
    /// Profile bound per native macOS Space, keyed by the
    /// Mission Control number (1-based). Populated by
    /// `bind_profile_to_native_space`.
    public internal(set) var nativeSpaceBindings: [Int: String] = [:]

    /// Log line consumer (GUI console later; syslog now).
    public var onLog: @MainActor (String) -> Void = { message in
        NSLog("KiwiDesk: %@", message)
    }

    /// Problems from the last config load (#68): a broken
    /// init.lua, an unreadable gui.json, invalid profile JSONs.
    /// Empty when the config loaded cleanly. Drives the
    /// menu-bar error badge and the Config Issues panel.
    public internal(set) var configIssues: [ConfigIssue] = []
    /// The load-scoped half of `configIssues` (init.lua /
    /// gui.json) — kept so profile mutations can refresh the
    /// profile half without losing these.
    var configLoadIssues: [ConfigIssue] = []
    /// Typo-guard hits from the init.lua chunk currently
    /// running (#39). Armed exclusively by
    /// `recordingTypoIssues`; nil gates runtime hits (a typo
    /// inside a keybinding closure) to log-only.
    var typoIssues: [ConfigIssue]?
    /// Fired whenever `configIssues` changes (including back
    /// to empty, so the badge clears itself).
    public var onConfigIssuesChange:
        @MainActor ([ConfigIssue])
            -> Void = { _ in }

    /// Fired by the `KiwiDesk.show_shortcuts()` Lua verb (#330):
    /// a bindable action that opens (toggles) the read-only
    /// shortcuts reference panel (#326). The VM holds no UI ref —
    /// Core just raises this hook and the GUI (`AppDelegate`) wires
    /// it to the panel controller, weakly. No-op until wired.
    public var onShowShortcuts: @MainActor () -> Void = {}

    /// `~/.config/KiwiDesk/` (created on demand).
    public let configDirectory: URL
    public var configURL: URL {
        configDirectory.appendingPathComponent("init.lua")
    }

    public let socket: SocketServer

    /// Where the CLI expects the running app's socket.
    public nonisolated static var defaultSocketPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                ".config/KiwiDesk/KiwiDesk.sock"
            ).path
    }

    public init(
        configDirectory: URL? = nil,
        hotkeyRegistrar: HotkeyRegistrar = CarbonHotkeyCenter()
    ) {
        let directory =
            configDirectory
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/KiwiDesk")
        self.configDirectory = directory
        self.keys = KeybindingManager(
            registrar: hotkeyRegistrar
        )
        self.socket = SocketServer(
            path:
                directory
                .appendingPathComponent("KiwiDesk.sock").path
        )
        self.profiles = ProfileManager(
            directory: directory.appendingPathComponent(
                "profiles"
            )
        )
        self.crash = CrashRecovery(directory: directory)

        bootstrapCoreServices()
    }
}
