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

    /// Last known space per window. Window ids are stable OS
    /// ids, so a "created" window with a remembered space is
    /// one coming back from another native macOS Space (or a
    /// session restore) and returns there instead of landing
    /// in the active space. Minimized windows are deliberately
    /// forgotten: deminiaturize opens in the active space.
    private var rememberedSpaces: [WindowID: SpaceID] = [:]

    /// Explicit `make_floating` / `make_tiled` verdicts per
    /// tracked window — the only float state worth carrying
    /// across close/reopen; detection re-derives the rest.
    private var manualFloatOverrides: [WindowID: Bool] = [:]

    /// Manual float intent of windows that closed (#160).
    /// Keyed by app + title, not `WindowID`: the OS reuses
    /// `CGWindowID`s, so a remembered id could resurrect the
    /// override onto an unrelated window. A drifted title on
    /// reopen misses — graceful degradation, the user just
    /// floats again. Entries are consumed on reopen; the rest
    /// linger for the session (manual floats are rare).
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
        windows.setFloating(id, floating)
        if windows[id] != nil {
            manualFloatOverrides[id] = floating
        }
    }

    public mutating func apply(_ event: KiwiEvent) {
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
            windows.upsert(window)
            // Reopened window: restore the manual float
            // intent over the fresh detection verdict, and
            // re-arm the override so the next close cycle
            // remembers it again (#160).
            if let intent = rememberedFloating.removeValue(
                forKey: WindowIdentity(of: window)
            ) {
                windows.setFloating(window.id, intent)
                manualFloatOverrides[window.id] = intent
            }
            let target =
                rememberedSpaces[window.id]
                ?? appRules[window.appName]
                ?? workspaces.activeSpace
            if let target {
                let mode = workspaces[target]?.mode ?? .bsp
                workspaces.add(
                    window.id,
                    to: target,
                    placement: spawnOverride[target]
                        ?? spawnPlacements[mode]
                        ?? .afterFocused
                )
                workspaces.focus(window.id, in: target)
            }

        case .windowDestroyed(let id, let wasMinimized):
            if wasMinimized {
                rememberedSpaces[id] = nil
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
            if let space = workspaces.space(of: id) {
                workspaces.focus(id, in: space)
            }

        case .windowTitleChanged(let id, let title):
            windows.updateTitle(id, title: title)

        case .windowFloatChanged(let id, let floating):
            // A changed detection verdict supersedes the live
            // window state (pre-existing semantics), so it
            // drops the manual override too — remembering the
            // stale intent would resurrect a float state the
            // user no longer sees (#160).
            manualFloatOverrides[id] = nil
            windows.setFloating(id, floating)

        case .displaysChanged(let displays):
            reconcile(displays: displays)

        case .nativeSpaceChanged:
            // Handled by KiwiCore (profile binding); the
            // internal state keys off the AX reconcile that
            // follows the switch.
            break
        }
    }

    /// Moves a window's manual float override (if any) into
    /// the close/reopen memory, keyed by its identity (#160).
    private mutating func rememberFloatOverride(
        of window: ManagedWindow
    ) {
        guard
            let intent = manualFloatOverrides.removeValue(
                forKey: window.id
            )
        else { return }
        rememberedFloating[WindowIdentity(of: window)] = intent
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
