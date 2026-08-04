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
        let home = workspaces.space(of: id)
        let tiledSlot = home.flatMap { space in
            workspaces[space].flatMap {
                effectiveTiledMembers(of: $0, activeSpace: space)
                    .firstIndex(of: id)
            }
        }
        return AppliedEffects.RemovedWindow(
            app: windows[id]?.appName,
            bundleID: windows[id]?.appBundleID,
            space: home,
            focusLost: focused == id,
            tiledSlot: tiledSlot
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
