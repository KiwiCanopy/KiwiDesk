import Foundation

/// Applies `KiwiEvent`s to the state managers.
///
/// This is the single write path for KiwiDesk's internal state:
/// the event loop produces events, the coordinator folds them into
/// `WindowManager` and `WorkspaceManager`. Pure and synchronous,
/// so the full pipeline is unit-testable without AX access.
public struct StateCoordinator: Sendable {
    public private(set) var windows = WindowManager()
    public internal(set) var workspaces = WorkspaceManager()

    /// `app_rules` from init.lua: new windows of these apps go
    /// to a fixed space instead of the active one.
    public var appRules: [String: SpaceID] = [:]

    /// `new_window_placement` per layout mode. Mirrored from
    /// the tiler settings before each event (KiwiCore), so it
    /// survives profile loads and live commands. Modes absent
    /// here (monocle, floating) fall back to `.afterFocused`.
    /// Defaults derive from the params structs so unit tests
    /// see production behavior.
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

    /// The advanced-track gate's single storage (#181),
    /// default OFF. Lives here — not on `KiwiCore` — so the
    /// two non-command consumers (this coordinator's
    /// `windowCreated` insertion and the tiling engine's
    /// `layoutInput(state:)` clamp) read the same bit with no
    /// mirror to forget. Everything else asks
    /// `KiwiCore.isTrackAdvanced`, which reads this.
    public var trackAdvanced = false

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
    private var manualFloatOverrides: [WindowID: Bool] = [:]

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
    private var rememberedFloating: [WindowIdentity: Bool] = [:]

    /// Stable close/reopen identity of a window (#160).
    private struct WindowIdentity: Hashable, Sendable {
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

    /// Marks a window floating/tiled (`make_floating`). The
    /// verdict is remembered as a manual override so it can
    /// survive the window closing and reopening (#160).
    public mutating func setFloating(
        _ id: WindowID,
        _ floating: Bool
    ) {
        guard windows[id] != nil else { return }
        windows.setFloating(id, floating)
        manualFloatOverrides[id] = floating
    }

    /// Returns a window to detection control (`make_auto`):
    /// clears its manual override and the close/reopen memory
    /// of its identity, so detection verdicts apply again and
    /// nothing resurrects the old intent on reopen (#164).
    public mutating func clearFloatOverride(_ id: WindowID) {
        manualFloatOverrides[id] = nil
        if let window = windows[id] {
            rememberedFloating[WindowIdentity(of: window)] = nil
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
            let target =
                rememberedSpaces[window.id]
                ?? appRules[window.appName]
                ?? workspaces.activeSpace
            if let target {
                let mode = workspaces[target]?.mode ?? .bsp
                if mode == .track, !window.isFloating {
                    let params =
                        (trackParams.override[target]
                        ?? TrackOverride())
                        .resolved(onto: trackParams)
                        .gated(advanced: trackAdvanced)
                    workspaces.add(
                        window.id,
                        to: target,
                        trackRule: params.newWindow,
                        cap: params.trackCap,
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
            windows.setFloating(id, floating)

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

    /// The facts a `.windowDestroyed` will erase: the window's
    /// app and space, and whether it held the active space's
    /// focus (so the caller can raise the fallback). Read before
    /// the removal mutates state.
    private func removalFacts(
        _ id: WindowID
    ) -> AppliedEffects.RemovedWindow {
        let focused =
            workspaces.activeSpace
            .flatMap { workspaces[$0]?.focused }
        return AppliedEffects.RemovedWindow(
            app: windows[id]?.appName,
            space: workspaces.space(of: id),
            focusLost: focused == id
        )
    }

    /// Moves a window's manual float override (if any) into
    /// the close/reopen memory, keyed by its identity (#160).
    /// An empty title carries no identity — every pre-title
    /// window of the app would match it — so the override is
    /// dropped instead of remembered.
    private mutating func rememberFloatOverride(
        of window: ManagedWindow
    ) {
        guard
            let intent = manualFloatOverrides.removeValue(
                forKey: window.id
            ),
            !window.title.isEmpty
        else { return }
        rememberedFloating[WindowIdentity(of: window)] = intent
    }

    /// Restores a remembered float intent onto a (re)tracked
    /// window: the manual verdict beats the fresh detection
    /// one, and the override re-arms so the next close cycle
    /// remembers it again (#160). Runs at creation and again
    /// on title changes (lazy-title apps); a live manual
    /// override is never clobbered.
    private mutating func restoreFloatOverride(
        of window: ManagedWindow
    ) {
        guard manualFloatOverrides[window.id] == nil,
            !window.title.isEmpty,
            let intent = rememberedFloating.removeValue(
                forKey: WindowIdentity(of: window)
            )
        else { return }
        windows.setFloating(window.id, intent)
        manualFloatOverrides[window.id] = intent
    }

    private mutating func reconcile(displays: [Display]) {
        let incoming = Set(displays.map(\.id))
        for old in workspaces.allDisplays
        where !incoming.contains(old.id) {
            workspaces.removeDisplay(old.id)
        }
        for display in displays {
            workspaces.upsertDisplay(display)
        }
    }
}
