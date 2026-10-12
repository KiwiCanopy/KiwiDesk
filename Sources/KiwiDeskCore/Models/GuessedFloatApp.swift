import Foundation

/// One app the Tile picker offers (#2071).
public struct GuessedFloatApp: Sendable, Equatable {
    /// Lowercased, as a Tile rule matches it.
    public let bundleID: String
    public let name: String
    /// The titles of its windows floating on a guess now.
    public let titles: [String]
}
