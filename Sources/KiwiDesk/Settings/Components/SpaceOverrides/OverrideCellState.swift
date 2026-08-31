import Foundation

/// Override badge and trigger cell display state for space rows
/// (#678 8a). A Floating space may still hold overrides saved for
/// OTHER layouts; hiding that count would reproduce the haunted
/// tiler (#458), so it stays visible — grey, don't hide.
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
