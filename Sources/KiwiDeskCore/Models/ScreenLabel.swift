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

/// Where a Desktop number a command takes lands now (#2792): the
/// screen it is on. Only with more than one screen connected; the
/// number is the command's own, as Mission Control counts across
/// screens (#3103).
public struct DesktopLanding: Sendable, Equatable {
    public let screen: ScreenLabel

    public init(screen: ScreenLabel) {
        self.screen = screen
    }
}
