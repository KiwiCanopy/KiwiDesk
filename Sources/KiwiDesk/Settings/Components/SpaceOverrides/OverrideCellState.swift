import Foundation

/// Override badge and trigger cell display state for space rows
/// (#678 8a). A Floating space may still hold overrides saved for
/// OTHER layouts; hiding that count would reproduce the haunted
/// tiler (#458), so it stays visible — grey, don't hide. Its own
/// minimum window size applies while it floats (#2422), so a
/// Floating space always has an editor to open.
enum OverrideCellState: Equatable {
    /// No overrides: the offer to add. "Customize…"
    case customize
    /// N overrides, some live in this mode. "N custom"
    case custom(Int)
    /// Floating space whose N overrides all wait for another
    /// layout. "N saved", muted — not live for this mode, but
    /// reachable.
    case saved(Int)

    /// `live` counts the overrides that apply while floating.
    static func resolve(
        count: Int,
        live: Int,
        isFloating: Bool
    ) -> OverrideCellState {
        if count == 0 { return .customize }
        if isFloating && live == 0 { return .saved(count) }
        return .custom(count)
    }
}
