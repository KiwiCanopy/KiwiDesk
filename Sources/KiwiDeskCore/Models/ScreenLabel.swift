import Foundation

/// A screen as a label names it (#2792): its own name, and its
/// place where another connected screen shares that name — its
/// index in `PositionalDisplays.ordered` — which the GUI narrates
/// as "Main screen" / "Screen 2" (#96).
public struct ScreenLabel: Sendable, Equatable {
    public let name: String
    /// Nil while the name is unique among the connected screens.
    public let twinPlace: Int?

    public init(name: String, twinPlace: Int? = nil) {
        self.name = name
        self.twinPlace = twinPlace
    }
}
