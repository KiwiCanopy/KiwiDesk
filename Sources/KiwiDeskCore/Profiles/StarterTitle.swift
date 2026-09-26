import Foundation

/// What a starter setup is called (#1662): the main screen's class,
/// plus how many other screens it spans. Identity stays
/// `StarterSetup.name` — held spaces and the monitor-change rescale
/// key on it — so this is a TITLE, and the GUI localizes it.
public struct StarterTitle: Sendable, Equatable {
    public let shape: ScreenClass
    /// Screens beside the main one; 0 for a single screen.
    public let otherScreens: Int

    public init(shape: ScreenClass, otherScreens: Int) {
        self.shape = shape
        self.otherScreens = max(0, otherScreens)
    }

    /// The English name a saved starter profile takes, like every
    /// shipped preset's: "Ultrawide", "Widescreen + 1".
    public var profileName: String {
        otherScreens > 0
            ? "\(Self.name(of: shape)) + \(otherScreens)"
            : Self.name(of: shape)
    }

    /// Canonical English class name.
    public static func name(of shape: ScreenClass) -> String {
        switch shape {
        case .laptop: "Laptop"
        // Never "Desktop": that noun is macOS's Mission Control
        // Desktop, which a profile can be bound to.
        case .desktop: "Widescreen"
        case .ultrawide: "Ultrawide"
        case .superUltrawide: "Super Ultrawide"
        case .pivoted: "Portrait"
        }
    }
}
