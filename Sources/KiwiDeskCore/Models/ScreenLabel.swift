import Foundation

/// A screen as a label names it (#2792): its own name, and its
/// place where another connected screen shares that name — 0 for
/// the main screen, then reading order — which the GUI narrates
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
/// screen it is on and its number there. Only with more than one
/// screen connected, where the two counts can differ.
public struct DesktopLanding: Sendable, Equatable {
    public let screen: ScreenLabel
    public let number: Int

    public init(screen: ScreenLabel, number: Int) {
        self.screen = screen
        self.number = number
    }
}
