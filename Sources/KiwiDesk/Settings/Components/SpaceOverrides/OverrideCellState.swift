import Foundation

/// What a space row's override cell reads, resolved purely from
/// the space's total saved-override count and whether its mode is
/// Floating (owner ruling 2026-08-04, #678 8a).
///
/// The count is the SUM across every layout
/// (`overrideFieldCount(for:)`) — the scannable "how much custom
/// config does this space carry" signal, which the pushed editor
/// then splits into active-layout rows and a dormant drawer.
///
/// Floating carries no *active* overrides, but a Floating space
/// may still hold overrides saved for OTHER layouts. Hiding that
/// count would reproduce the "haunted tiler" (#458): a Floating
/// space silently carrying tiling overrides the user cannot see,
/// which reactivate the moment the space switches back. So the
/// count stays visible and the cell stays a way into the editor —
/// "grey, don't hide" (§2.7). Only a Floating space with nothing
/// parked is genuinely inert.
enum OverrideCellState: Equatable {
    /// Tiled space, no overrides: the offer to add. "Customize…"
    case customize
    /// Tiled space with N overrides. "N custom"
    case custom(Int)
    /// Floating space with N overrides saved for other layouts.
    /// "N saved", muted — not live for this mode, but reachable.
    case saved(Int)
    /// Floating space with nothing saved: "—", no destination.
    case inert

    static func resolve(
        count: Int,
        isFloating: Bool
    ) -> OverrideCellState {
        if isFloating {
            return count == 0 ? .inert : .saved(count)
        }
        return count == 0 ? .customize : .custom(count)
    }

    /// The one state with no editor to open — the cell disables.
    var isInert: Bool { self == .inert }
}
