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

    public init(defaultSpace: SpaceID = SpaceID(1)) {
        workspaces.ensureSpace(defaultSpace)
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
                appRules[window.appName]
                ?? workspaces.activeSpace
            if let target {
                workspaces.add(window.id, to: target)
                workspaces.focus(window.id, in: target)
            }

        case .windowDestroyed(let id):
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

        case .displaysChanged(let displays):
            reconcile(displays: displays)
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
