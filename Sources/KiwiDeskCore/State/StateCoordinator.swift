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

    public init(defaultSpace: SpaceID = SpaceID(1)) {
        workspaces.ensureSpace(defaultSpace)
    }

    /// Notes where a currently-untracked window belongs (see
    /// rememberedSpaces; used by session restore).
    mutating func remember(_ id: WindowID, in space: SpaceID) {
        rememberedSpaces[id] = space
    }

    /// Marks a window floating/tiled (`make_floating`).
    public mutating func setFloating(
        _ id: WindowID,
        _ floating: Bool
    ) {
        windows.setFloating(id, floating)
    }

    public mutating func apply(_ event: KiwiEvent) {
        switch event {
        case .appLaunched:
            break

        case .appTerminated(let pid):
            for id in windows.removeAll(pid: pid) {
                workspaces.remove(id)
            }

        case .windowCreated(let window):
            windows.upsert(window)
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
