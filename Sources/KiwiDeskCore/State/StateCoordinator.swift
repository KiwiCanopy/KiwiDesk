import Foundation

/// Applies `KiwiEvent`s to the state managers.
///
/// This is the single write path for KiwiDesk's internal state:
/// the event loop produces events, the coordinator folds them into
/// `WindowManager` and `WorkspaceManager`. Pure and synchronous,
/// so the full pipeline is unit-testable without AX access.
public struct StateCoordinator: Sendable {
    // internal(set), like `workspaces`: the intent split
    // (`+Intents.swift`) mutates it from its own file.
    public internal(set) var windows = WindowManager()
    public internal(set) var workspaces = WorkspaceManager()

    /// `app_rules` from init.lua: new windows of these apps go
    /// to a fixed space instead of the active one.
    public var appRules: [String: SpaceID] = [:]

    /// `new_window_placement` per layout mode. Mirrored from
    /// the tiler settings before each event (KiwiCore) — which
    /// also seeds `.monocle` from `MonocleParams` — so it
    /// survives profile loads and live commands. This
    /// compile-time literal omits monocle (seeded at runtime)
    /// and floating (no tiled slot); both fall back to
    /// `.afterFocused` before the first event. Defaults derive
    /// from the params structs so unit tests see production
    /// behavior.
    public var spawnPlacements: [LayoutMode: SpawnPlacement] = [
        .bsp: BspParams().newWindowPlacement,
        .stack: StackParams().newWindowPlacement,
        .scrolling: ScrollingParams().newWindowPlacement,
        .grid: GridParams().newWindowPlacement,
    ]

    /// Per-space `new_window_placement_override`: beats the
    /// layout's spawn placement, like the gap override.
    public var spawnOverride: [SpaceID: SpawnPlacement] = [:]

    /// The track layout's params (#128), mirrored from the
    /// tiler settings like `spawnPlacements`: a new **tiled**
    /// window in a track space follows `new_window`/`count`
    /// instead of a `SpawnPlacement` (the flat-index vocabulary
    /// cannot say "own track"). A floating window still takes
    /// the `SpawnPlacement` path (it has no track slot), so its
    /// array position — and thus which track it would join if
    /// it later tiles — honors the placement override as in
    /// every other mode.
    public var trackParams = TrackParams()

    /// Per-space fill-then-spill capacity (#437), mirrored from the
    /// tiler before each event like `trackParams`: how many windows
    /// a track holds at `min_window_size` before a `focused_track`
    /// spawn spills into a new track beside the focused one. The
    /// number is geometry-derived (the space's display), computed
    /// where the geometry lives (`TilingEngine.trackCapacities`) so
    /// this state core stays pure. An absent entry (unknown display)
    /// makes the spawn join-and-pile — the same safe fallback a
    /// traveler takes.
    public var trackCapacities: [SpaceID: Int] = [:]

    /// Last known space per window. Window ids are stable OS
    /// ids, so a "created" window with a remembered space is
    /// one coming back from another native macOS Space (or a
    /// session restore) and returns there instead of landing
    /// in the active space. Minimized windows are deliberately
    /// forgotten: deminiaturize opens in the active space.
    private var rememberedSpaces: [WindowID: SpaceID] = [:]

    /// Windows currently minimized, so their deminiaturize
    /// (`.windowCreated`) classifies as `restored` (#40). Lives
    /// here beside `rememberedSpaces` — both are memory carried
    /// across tracking gaps. An entry for a window that closes
    /// while minimized goes stale (no event fires): session-
    /// scoped and tiny, but slightly weaker than
    /// `rememberedSpaces`' staleness — these are DEAD ids, so a
    /// recycled WindowID could pin `restored` onto an unrelated
    /// window. The payload is advisory; accepted.
    private var minimizedWindows: Set<WindowID> = []

    /// Explicit `make_floating` / `make_tiled` verdicts per
    /// tracked window — the only float state worth carrying
    /// across close/reopen; detection re-derives the rest.
    /// Internal, not private: the intent logic lives in
    /// `StateCoordinator+Intents.swift` (file-ceiling split).
    var manualFloatOverrides: [WindowID: Bool] = [:]

    /// Manual float intent of windows that closed (#160).
    /// Keyed by app + title, not `WindowID`: a reopened window
    /// gets a fresh id, and old ids can be recycled onto
    /// unrelated windows (`rememberedSpaces` above can key on
    /// ids because a native-Space return keeps the window
    /// alive). Two live windows sharing an identity share one
    /// slot: last close wins, first reopen consumes — at worst
    /// one misapplied float, corrected with one command. A
    /// drifted title on reopen misses the same gracefully.
    /// Unconsumed entries linger for the session, mirroring
    /// `rememberedSpaces`' lifetime (manual floats are rare).
    var rememberedFloating: [WindowIdentity: Bool] = [:]

    /// Sticky intent of windows that closed (#414/#445), mirroring
    /// `rememberedFloating`'s identity keying and lifetime. A map
    /// now that sticky carries a SCOPE (`.global` / `.display`):
    /// an absent identity means "not sticky" (`.none` is never
    /// stored), so the close of a non-sticky window drops its
    /// entry (last close wins, like float).
    var rememberedSticky: [WindowIdentity: StickyScope] = [:]

    /// Stable close/reopen identity of a window (#160).
    struct WindowIdentity: Hashable, Sendable {
        let app: String
        let title: String

        init(of window: ManagedWindow) {
            app = window.appName
            title = window.title
        }
    }

    public init(defaultSpace: SpaceID = SpaceID(1)) {
        workspaces.ensureSpace(defaultSpace)
    }

    /// Notes where a currently-untracked window belongs (see
    /// rememberedSpaces; used by session restore).
    mutating func remember(_ id: WindowID, in space: SpaceID) {
        rememberedSpaces[id] = space
    }

    /// Where an untracked window will be filed once tracked.
    /// Session restore fills this before slow-AX apps list
    /// their windows, so startup can land on the right space
    /// even when the window itself is not tracked yet.
    func rememberedSpace(of id: WindowID) -> SpaceID? {
        rememberedSpaces[id]
    }

    /// Swaps a window's tracked id in place across every id-keyed
    /// map this coordinator owns — window snapshot, space slot
    /// (position + focus + weights), plus the three cross-tracking
    /// maps below — for a native-tab active-tab change (#308). This
    /// is the hand-mirrored id-keyed field list AGENTS.md §5 warns
    /// about: forgetting a map is silent data loss, so
    /// `WindowRekeyParityTests` discovers every WindowID-keyed
    /// container by reflection and fails if one still holds `old`.
    /// `rememberedFloating` is keyed by app+title, not WindowID, so
    /// it is deliberately untouched. No-op if `old` is untracked.
    mutating func rekey(_ old: WindowID, to new: WindowID) {
        windows.rekey(old, to: new)
        workspaces.rekey(old, to: new)
        if let space = rememberedSpaces.removeValue(forKey: old) {
            rememberedSpaces[new] = space
        }
        if minimizedWindows.remove(old) != nil {
            minimizedWindows.insert(new)
        }
        if let intent = manualFloatOverrides.removeValue(
            forKey: old
        ) {
            manualFloatOverrides[new] = intent
        }
    }

    /// Folds an event into state and returns the facts the write
    /// erases, for `handle(_:)` to compose its side effects from
    /// (#166). `@discardableResult` — command and test call sites
    /// apply purely for the state change.
    @discardableResult
    public mutating func apply(
        _ event: KiwiEvent
    ) -> AppliedEffects {
        var effects = AppliedEffects()
        switch event {
        case .appLaunched:
            break

        case .appTerminated(let pid):
            for window in windows.windows(pid: pid) {
                rememberFloatOverride(of: window)
                rememberStickyIntent(of: window)
            }
            for id in windows.removeAll(pid: pid) {
                workspaces.remove(id)
            }

        case .windowCreated(let window):
            effects.appearedWasMinimized =
                minimizedWindows.remove(window.id) != nil
            effects.hadRememberedSpace =
                rememberedSpaces[window.id] != nil
            windows.upsert(window)
            restoreFloatOverride(of: window)
            restoreStickyIntent(of: window)
            let target =
                rememberedSpaces[window.id]
                ?? window.appBundleID.flatMap { appRules[$0] }
                ?? workspaces.activeSpace
            if let target {
                let mode = workspaces[target]?.mode ?? .bsp
                let track =
                    mode == .track
                    ? (trackParams.override[target]
                        ?? TrackOverride())
                        .resolved(onto: trackParams)
                    : nil
                if let track, !window.isFloating {
                    workspaces.add(
                        window.id,
                        to: target,
                        trackRule: track.newWindow,
                        trackPosition: track.newWindowPosition,
                        spillCapacity: trackCapacities[target],
                        trackCap: track.trackCap,
                        isTiled: { [windows] in
                            windows[$0]?.isFloating == false
                        }
                    )
                } else {
                    workspaces.add(
                        window.id,
                        to: target,
                        placement: spawnOverride[target]
                            ?? spawnPlacements[mode]
                            ?? .afterFocused
                    )
                    // A floating window spawned into an
                    // `own_track` space carries a dormant break
                    // marker, matching what the mode-entry seed
                    // gives every window (`setMode`): when a
                    // float re-check heals it to tiled (#160),
                    // it opens its own track at its slot instead
                    // of silently merging into its array
                    // neighbor's track. `focused_track` stays
                    // markerless — joining by position is that
                    // rule's meaning.
                    if track?.newWindow == .ownTrack {
                        workspaces.withSpace(target) {
                            $0.trackBreaks.insert(window.id)
                        }
                    }
                }
                workspaces.focus(window.id, in: target)
            }

        case .windowDestroyed(let id, let wasMinimized):
            effects.removedWindow = removalFacts(id)
            if wasMinimized {
                rememberedSpaces[id] = nil
                minimizedWindows.insert(id)
            } else if let space = workspaces.space(of: id) {
                rememberedSpaces[id] = space
            }
            // Float intent is remembered even for minimized
            // windows: deminiaturize re-tracks from detection
            // and would lose a manual override too (#160).
            if let window = windows[id] {
                rememberFloatOverride(of: window)
                rememberStickyIntent(of: window)
            }
            windows.remove(id)
            workspaces.remove(id)

        case .windowMoved(let id, let frame):
            windows.updateFrame(id, frame: frame)

        case .windowResized(let id, let frame):
            windows.updateFrame(id, frame: frame)

        case .windowFocused(let id):
            effects.focusBefore = workspaces.activeSpace
                .flatMap { workspaces[$0]?.focused }
            if let space = workspaces.space(of: id) {
                workspaces.focus(id, in: space)
            }

        case .windowTitleChanged(let id, let title):
            let floatBefore = windows[id]?.isFloating
            windows.updateTitle(id, title: title)
            // Lazy-title apps (Electron/WebKit) are tracked
            // before their titles arrive, so the create-time
            // identity match misses; retry once the real
            // title lands (#160).
            if let window = windows[id] {
                restoreFloatOverride(of: window)
                restoreStickyIntent(of: window)
            }
            // A late title can restore a remembered float
            // override — the only title change that retiles.
            if let floatBefore,
                windows[id]?.isFloating != floatBefore
            {
                effects.floatFlipped = true
            }

        case .windowFloatChanged(let id, let floating):
            // A manual override always wins over detection:
            // the title recheck (#160) makes verdicts flip
            // routinely for `App:Title` rules, and a flip must
            // not revert an explicit make_floating/make_tiled
            // (docs promise re-checks never do).
            guard manualFloatOverrides[id] == nil else { break }
            // `windows.setFloating` also clears any stale overlay
            // flag when a window heals back to tiled (#300).
            windows.setFloating(id, floating)

        case .windowFullscreenChanged(let id, let fullscreen):
            // No override layer here (unlike float): fullscreen
            // is purely AX-detected, so the re-check verdict
            // always applies.
            windows.setFullscreen(id, fullscreen)

        case .windowRekeyed(let old, let new):
            rekey(old, to: new)

        case .displaysChanged(let displays):
            reconcile(displays: displays)

        case .nativeSpaceChanged:
            // Handled by KiwiCore (profile binding); the
            // internal state keys off the AX reconcile that
            // follows the switch.
            break
        }
        return effects
    }
}

// `effectiveMembers` / `effectiveTiledMembers` live in
// `StateCoordinator+EffectiveMembers.swift` (file-ceiling
// split, #414 v2).
