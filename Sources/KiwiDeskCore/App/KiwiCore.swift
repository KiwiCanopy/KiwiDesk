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
    var appliedStructuredLayers: [KeyLayer]?
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

    /// Boot's half of the same suppression (#836). **Raised in
    /// `start()`, lowered where the startup sweep is armed** —
    /// one pair, because the skip is valid exactly while nothing
    /// has yet armed the pass that heals it. Every exit from
    /// `start()` lowers it, `stop()` included. What it buys, what
    /// it costs, and why it is not keyed on `BootPhase` are
    /// argued at its one reader, `mayReconcileWindowRulesNow`.
    var defersWindowRuleReconcileToSweep = false

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

    /// Windows raised purely for z-order (#418 floats, #425 pile
    /// restores), stamped per raise sequence. Their focus echoes
    /// carry no self-raise provenance (#152), so a fresh stamped
    /// report that is not the intended focus is reverted unless
    /// it carries click provenance (#687 — the design-decisions
    /// entry owns the ruling). Age-pruned, cleaned on
    /// destroy/rekey, and NEVER consumed by an echo: lazy apps
    /// re-report, and the unstamped duplicate was honored as
    /// deliberate focus (#689).
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

    /// Trusted OS-frontmost focused window id (#1130); nil until
    /// `start()` wires the #442 chain (the `frontmostPIDProvider`
    /// pattern), so unit tests never read the host's focus.
    var trustedFrontmostProvider: (@MainActor () -> WindowID?)?

    /// The wake heal arm's timestamp (#1130) —
    /// `KiwiCore+WakeFocus.swift` is the one machine mutating it.
    var wakeFocusHealArmedAt: Date?

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

    /// The ignored-panel distrust (#21/#244/#951) — the state's
    /// own docs, and the one state machine mutating it, live in
    /// `KiwiCore+IgnoredPanel.swift`.
    var ignoredPanel = IgnoredPanelDistrust()

    /// #958 steal debt; `KiwiCore+AccessibilityReturn.swift`.
    var accessibilityReturn: AccessibilityReturnDebt?

    /// Z-order restores whose raises have not re-asserted focus
    /// yet (#186); their echoes lack provenance (#152), so the
    /// mouse warp holds while any restore is in flight. A count —
    /// restores overlap. WARP-scoped (#689): `warpMouseToFocused`
    /// and `runPendingMouseWarp` are the only readers; a consumer
    /// outside the warp closes #152's gap properly instead.
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

    /// The in-flight boot's phase, spans and timestamps (#801).
    let boot = BootRun()

    /// Adoption-heal timings (#675); tests assign milliseconds.
    /// 5 s: a healthy tick is one ~1 ms census, so the cadence
    /// only bounds worst-case adoption latency. 750 ms: outlasts
    /// a Dock-stack zoom or fade-in, still feels immediate.
    var adoptionHealInterval: Duration = .seconds(5)
    var transientRetrackDelay: Duration = .milliseconds(750)

    /// Windows just moved without follow, whose focus re-reports
    /// must not space-follow (#482/#483) — see the type doc.
    let moveLatch = MoveIntentLatch()

    /// The focus a `move_to_desktop_and_follow` owes the window
    /// it sent away (#1007) — the type doc carries the argument.
    let followFocus = FollowFocusIntent()

    /// The MAIN display's current native Desktop (Mission
    /// Control number, #888) — the binding authority — and the
    /// per-display Space memory restored on returning to one.
    var lastDesktop: Int?
    let desktopMemory = DesktopMemory()
    /// When the last native desktop switch happened; focus
    /// events during the transition must not change spaces.
    var lastDesktopSwitch: Date = .distantPast

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
    /// `bind_profile_to_desktop`.
    public internal(set) var desktopBindings: [Int: String] = [:]

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

    /// Fired after a CAPTURE-LIVE profile write lands — the
    /// quick menu's Keep and the `save_profile` command alike.
    ///
    /// On the WRITE rather than on either caller (#1179): an
    /// open Settings draft seeds its modes from the saved
    /// profile, so a capture-live write moves the file under it
    /// and the draft's baseline has to follow, or the next
    /// Settings Save commits the pre-write modes back over what
    /// was just saved. A draft-commit write is NOT one of these
    /// — it wrote the draft's own modes, so the baseline is
    /// already right.
    public var onProfileCapturedLive: @MainActor (String) -> Void =
        { _ in }

    /// The UI-bridge verbs' GUI hooks (#330, #678 item 18) —
    /// declared and argued as a bundle in `KiwiCore+LuaAPI`,
    /// the `openOrFocus` seam shape.
    public var uiBridge = UIBridgeHooks()

    /// `~/.config/KiwiDesk/` (created on demand).
    public let configDirectory: URL

    public let socket: SocketServer

    public init(
        configDirectory: URL? = nil,
        hotkeyRegistrar: HotkeyRegistrar = CarbonHotkeyCenter()
    ) {
        // The helpers live in `KiwiCore+Init`; a designated
        // initializer cannot.
        let directory = Self.resolveConfigDirectory(
            configDirectory
        )
        self.configDirectory = directory
        self.keys = KeybindingManager(registrar: hotkeyRegistrar)
        self.socket = Self.makeSocketServer(in: directory)
        self.profiles = Self.makeProfileManager(in: directory)
        self.crash = CrashRecovery(directory: directory)
        bootstrapCoreServices()
    }
}
