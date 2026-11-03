import CoreGraphics

/// The length a push along a run gave a window (#2709,
/// `Space.runSizes`): a share of the run's span, and the role of the
/// zone it was given in (`RunZone.ordinal`). A window planned in a
/// zone of another role, or in a run that would show everything at
/// its floors, plans at its floor and share (`RunZone`).
public struct RunSize: Sendable, Equatable, Codable {
    /// The window's length over the run's span, 0…1.
    public var share: CGFloat
    /// The role of the zone the length was given in
    /// (`RunZone.ordinal`).
    public var zone: Int

    public init(share: CGFloat, zone: Int) {
        self.share = share
        self.zone = zone
    }

    /// The in-place payload's keys, a stored cross-version shape
    /// (#930, `RunSizeCodingTests`).
    private enum CodingKeys: String, CodingKey {
        case share
        case zone
    }
}

extension Dictionary where Key == WindowID, Value == RunSize {
    /// The entry under `old` moved to `new` — the re-key and the
    /// trade both take it.
    mutating func rename(_ old: WindowID, to new: WindowID) {
        if let size = removeValue(forKey: old) { self[new] = size }
    }
}
