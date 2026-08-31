import Foundation

/// Screen home space resolution for cross-display moves (#1010).
///
/// Shared predicate between create fold
/// (`StateCoordinator+WindowCreated`) and
/// Desktop command dispatch (`KiwiCore+DesktopCommands`).
extension StateCoordinator {
    /// Space the window should join when landing on display (#1010).
    ///
    /// Floating (#444, #412) and sticky windows (#445, #1008, #890) stand
    /// down.
    func screenHome(
        of window: ManagedWindow,
        leaving home: SpaceID?,
        landingOn display: DisplayID?
    ) -> SpaceID? {
        guard !window.isFloating,
            !window.isSticky,
            let home,
            let display,
            let current = workspaces.display(of: home),
            current != display,
            let destination = workspaces.activeSpace(on: display),
            destination != home
        else { return nil }
        return destination
    }
}
