import Foundation

/// SCREEN WINS (#1010) — the ONE copy of the predicate, asked at
/// two altitudes about the same question: a window is on (or is
/// being sent to) a screen other than the one its KiwiDesk space
/// lays out on, so which space should it belong to?
///
/// - The **create fold** asks it about a window coming back,
///   for a departure it watched (`StateCoordinator+WindowCreated`).
/// - The **Desktop verb** asks it before the window leaves, for
///   a Desktop that lives on another screen
///   (`KiwiCore+DesktopCommands`).
///
/// Both need it because they are different routes to one defect,
/// and only one of them fires per move: a Desktop the target
/// screen is not showing takes the window out of KiwiDesk's view
/// and the answer is owed on its return; a Desktop that screen
/// IS showing produces no departure at all, and the answer is
/// owed at once — device-measured both ways, 2026-08-25, which
/// is why a fix on either altitude alone left the other route
/// snapping the window back inside a second.
///
/// Pure state: the frame→screen resolution each caller needs is
/// `NSScreen`'s and stays above this core (§2.6).
extension StateCoordinator {
    /// The space `window` should join when it lands on
    /// `display`, or nil when nothing should move.
    ///
    /// Every stand-down, and why each one is not the ruled case:
    ///
    /// - **A FLOATING window** — the defect is the layout
    ///   carrying a window home, and a float is never laid out,
    ///   so it never gets carried. Its display anchoring is
    ///   #444's and #412's, whose residues
    ///   `docs/accepted-limitations.md` already rules; nothing
    ///   here re-opens them.
    /// - **A STICKY window of either scope** — re-homing a
    ///   sticky is the one membership move `stickyMoveRefused`
    ///   (#445) gates at every command choke point, and neither
    ///   caller may quietly make it: a pure fold cannot call
    ///   that gate at all, and #1008 ruled that a Desktop move
    ///   leaves a sticky window's KiwiDesk membership alone.
    ///   Sticky reach across Desktops is #890's own item.
    /// - **No landing display**, or the window belongs to no
    ///   space, or its space is assigned to no display yet
    ///   (early boot, a detached monitor).
    /// - **The two are the SAME display** — which is every
    ///   single-screen move — or that display shows nothing, or
    ///   shows the space the window is already in.
    ///
    /// The window is passed rather than looked up so the create
    /// fold can hand in the record STATE holds (#671's rule):
    /// the float and sticky restores run before it asks.
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
