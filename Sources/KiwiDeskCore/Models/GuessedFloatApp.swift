import Foundation

/// One app the Tile picker offers (#2071).
public struct GuessedFloatApp: Sendable, Equatable {
    /// Its rule key, as a Tile rule matches it: a bundle id, or a
    /// process name where the app has none (#3211).
    public let bundleID: String
    public let name: String
    /// The titles of its windows floating on a guess now.
    public let titles: [String]
}
