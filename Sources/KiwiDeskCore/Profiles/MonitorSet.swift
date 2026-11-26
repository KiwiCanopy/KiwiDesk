import Foundation

/// A screen setup a profile is saved for (#36): its screens'
/// fingerprints (`Name:WxH`) in the order that numbers them —
/// Screen k is `monitors[k - 1]` (#3647). Matching ignores the
/// order and compares the screens as a sorted array, a multiset,
/// so two identical screens never collapse the way a `Set` would;
/// compare through `matches` or `sortedKey`, never `monitors ==`.
public struct MonitorSet: Codable, Sendable, Equatable {
    public private(set) var monitors: [String]

    private enum CodingKeys: String, CodingKey {
        case monitors
    }

    public init(monitors: [String]) {
        self.monitors = monitors
    }

    /// The screens as a multiset — the matching key.
    public var sortedKey: [String] { monitors.sorted() }

    /// Whether `fingerprints` are this setup's screens, in any order.
    public func matches(_ fingerprints: [String]) -> Bool {
        sortedKey == fingerprints.sorted()
    }

    /// Whether `other` covers the same screens.
    public func matches(_ other: MonitorSet) -> Bool {
        matches(other.monitors)
    }

    /// The order this setup numbers its screens by.
    public var order: ScreenOrder { ScreenOrder(monitors) }
}

extension Array where Element == MonitorSet {
    /// The order of the set covering `fingerprints`: the one
    /// spelling of "which stored set numbers these screens".
    public func order(matching fingerprints: [String]) -> ScreenOrder? {
        first { $0.matches(fingerprints) }?.order
    }
}
