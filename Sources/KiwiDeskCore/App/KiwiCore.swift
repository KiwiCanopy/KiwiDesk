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
    /// Glyph-vs-image icon decisions for bar items (#294) —
    /// App Bar, Space Bar (#293), shortcuts panel.
    public let appFont = AppFontResolver()
    /// Focus-window border overlays (#278), driven by
    /// `updateBorders()` inside `retile()`.
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

    /// The boot scan and the startup sweep surface N windows in
    /// one burst, and each `.windowCreated` would run a full
    /// retile + bars + borders + clamp — N passes for one
    /// arrangement (#672). While raised, `handle` skips its
    /// structural retile; the raiser runs one `retile()` after
    /// lowering it. The `defersWindowRuleReconcile` shape, for
    /// the same reason.
    var defersEventRetiles = false

    /// A z-order restore is waiting for the current animations
    /// to settle (`runPendingZOrderRestore`).
    var pendingZOrderRestore = false

    /// A command reordered windows but its paired retile is the
    /// dispatcher's own trailing `retile(force:)`, not one it
    /// issued itself (#153) — `layoutCommand` arms the z-order
    /// restore *after* that retile so it can't fire mid-retile
    /// from pre-retile frames. Set via
    /// `requestZOrderRestoreAfterDispatch`; reset each dispatch.
    var deferredCommandZOrderRestore = false

    /// What the layout sub-API's *one* trailing `retile` may
    /// promise about this dispatch's sizing (#593). The whole
    /// `stack.*` / `bsp.* `/ `scroll.* ` surface shares that single
    /// retile, and its members differ: a ratio write re-divides
    /// room among windows already placed, while `set_master_count`
    /// or `set_limit` reassign slots wholesale. So the ratio
    /// writers raise this where they write, and `layoutCommand`
    /// consumes it — the `deferredCommandZOrderRestore` shape
    /// directly above, for the same reason.
    ///
    /// Set at the write, not from a list of command names in this
    /// file: the names come in global/`_override` pairs, and a
    /// list has to enumerate that cross product from somewhere
    /// the maintainer adding a knob never looks. It shipped one
    /// round with exactly that bug — `bsp.set_ratio_h` marked,
    /// `bsp.set_ratio_h_override` not, same knob, two animations.
    ///
    /// **Reset at dispatch entry, not on consume.** A failed
    /// command returns before the retile, so a consume-only reset
    /// would leave this raised for the *next* dispatch and animate
    /// an unrelated `set_mode` as a promised pass.
    ///
    /// **One reader, and it must stay one.** `layoutCommand`'s
    /// trailing retile is the only consumer, and it sits
    /// downstream of that entry reset — which is the whole reason
    /// a stale raise cannot escape. The raise helper is
    /// `internal`, so a second reader anywhere in the module would
    /// observe a raise left by a dispatch whose retile never ran.
    /// Do not add one.
    var commandSizing: BatchSizing = .mayInstantSize

    /// A scrolling focus move whose AX raise is waiting for
    /// the pan to settle (#143) — a single slot, so rapid
    /// focus commands supersede each other and only the last
    /// target raises (see runPendingFocusRaise).
    var pendingFocusRaise: WindowID?

    /// Window ids KiwiDesk's own AX raises issued but whose
    /// focus echoes have not yet landed (#152). A matching echo
    /// is self-inflicted, not a user action: it must not
    /// supersede a newer focus nor snap state focus back. A set
    /// — two can be outstanding at once (#158). An entry counts
    /// as an echo only while `selfRaiseStamps` says the raise
    /// is RECENT: an already-key raise echoes never, and an
    /// unbounded entry ate the next click on that window (#687
    /// device QA). Removed on echo and destroy (ids reused);
    /// the classification lives in `handleWindowFocused`.
    var outstandingSelfRaises: Set<WindowID> = []

    /// When each self-raise was issued — the recency bound for
    /// the sibling-report distrust (#465) and for the self-echo
    /// classification itself (#687). Age-compared and pruned on
    /// write, never consumed, so a raise that never echoes
    /// cannot poison anything forever.
    var selfRaiseStamps: [WindowID: Date] = [:]

    /// Last left press, AX coords: the click discriminator for
    /// the cross-display sibling distrust (#496,
    /// `recentClickInside`) and the raise-echo revert's escape
    /// (#687, `recentClickReached`). `reached` is the managed
    /// window the press hit, resolved AT PRESS TIME
    /// (`clickReachedWindow` has the argument). Stamped in
    /// `KiwiCore+Lifecycle` (`ClickProvenanceWiringTests`).
    var lastLeftClick: (at: Date, point: CGPoint, reached: WindowID?)?

    /// The WindowServer's front-to-back stacking, resolving
    /// which window a left press reached (#687) — overlapping
    /// pile frames make containment alone ambiguous. nil until
    /// `start()` wires it (`ClickProvenanceWiringTests`), so
    /// unit tests never read the host's real windows (the
    /// `frontmostPIDProvider` pattern); nil resolves no
    /// provenance.
    var stackingOrderProvider: (@MainActor () -> [WindowID])?

    /// Windows raised purely for z-order, stamped with the
    /// raise time — floats promoted above the tiled plane
    /// (#418) and the pile members a restore re-raises (#425).
    /// A raise couples with app activation and echoes a focus
    /// report with no self-raise provenance (#152); a fresh
    /// stamped report that is not the intended focus is that
    /// echo — reverted, unless it carries click provenance
    /// (#687; the design-decisions entry owns the ruling).
    /// Stamped per sequence, age-pruned, cleaned on
    /// destroy/rekey — and NEVER consumed by an echo: lazy
    /// apps re-report a raised window, and the unstamped
    /// duplicate was honored as deliberate focus (#689 QA).
    var zOrderRaiseEchoes: [WindowID: Date] = [:]

    /// Bumped per z-order raise sequence (float raise or pile
    /// restore) so a stale sequence's focus handoff cannot
    /// steal focus back (the `runPendingFocusRaise` staleness
    /// pattern) — safe to pair with a live-focus check only
    /// because the `zOrderRaiseEchoes` revert keeps focus on
    /// the real target. A counter OBJECT rather than an `Int`
    /// because the drain re-reads it off the main actor between
    /// raises — `ZOrderGeneration` carries that argument.
    let zOrderRaiseGeneration = ZOrderGeneration()

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

    /// Every machine touch Open or Focus's already-running branch
    /// makes (#673) — app lookup, window census, deminiaturize,
    /// activate. Declared and argued as a bundle in
    /// `KiwiCore+LaunchRestore.swift`, all four live by default.
    var openOrFocus = OpenOrFocusSeams()

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
    /// WARP-scoped by design, and again in fact since #689
    /// retired the monocle arm's read: the hold in
    /// `warpMouseToFocused` and its release
    /// (`runPendingMouseWarp`) are the only readers. A consumer
    /// outside the warp is the signal to close #152's gap
    /// properly, not to extend this.
    var zOrderRestoresInFlight = 0

    /// The warp a draining restore held (#689): recorded while
    /// the counter above is up, fired when the last drain ends,
    /// staleness-checked (the `runPendingFocusRaise` pattern).
    /// Without it, a focus change landing inside a drain lost
    /// its warp forever.
    var pendingMouseWarp: WindowID?

    /// The machine tail of the warp (#186): reads the live
    /// cursor, moves the pointer. nil until `start()` wires it,
    /// so unit tests never move the developer's pointer (the
    /// `frontmostPIDProvider` pattern).
    var pointerWarp: (@MainActor (CGRect) -> Void)?

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

    /// Log line consumer (GUI console later; syslog now) — the
    /// sink every Core seam is wired to forward *into*.
    public var onLog: @MainActor (String) -> Void = CoreLog.write

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

    public let socket: SocketServer

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
