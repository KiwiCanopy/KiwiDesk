import Foundation

/// A Space row's override count state, drawn by the Customize
/// button's badge and spoken as its value (#678 8a, #2674). A
/// Floating space may still hold overrides saved for OTHER
/// layouts; hiding that count would reproduce the haunted tiler
/// (#458), so it stays visible — grey, don't hide. Its own minimum
/// window size applies while it floats (#2422), so a Floating
/// space always has an editor to open.
enum OverrideCellState: Equatable {
    /// No overrides: no badge; spoken "None".
    case customize
    /// N overrides, some live in this mode: the badge at full ink.
    case custom(Int)
    /// Floating space whose N overrides all wait for another
    /// layout: the badge dimmed — not live for this mode, but
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
