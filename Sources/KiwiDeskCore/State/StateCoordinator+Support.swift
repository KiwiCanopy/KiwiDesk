import Foundation

extension StateCoordinator {
    /// The facts a `.windowDestroyed` will erase: the window's app
    /// and space, and whether it held the active space's focus (so
    /// the caller can raise the fallback). Read before the removal
    /// mutates state.
    func removalFacts(
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

    /// Folds a display topology change into the workspace manager:
    /// drops vanished displays and upserts current ones.
    mutating func reconcile(displays: [Display]) {
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
