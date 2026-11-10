import Foundation

/// How an arriving window may take the focus, decided in Core ahead
/// of the fold and mirrored in (`StateCoordinator.arrivalFocus`).
public enum ArrivalFocus: Equatable, Sendable {
    /// Its app holds the keys: a new window takes the focus.
    case foreground
    /// Another app holds them (#3152): a new window takes none,
    /// save into a Space with no focus at all.
    case background
    /// A quiet open (#3122, #3141): no focus, no rule follow, and
    /// filed into `into` where the open named a Space.
    case quiet(into: SpaceID?)
}
