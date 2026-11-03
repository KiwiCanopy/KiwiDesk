import CoreGraphics

/// The length a push along a run gave a window (#2709,
/// `Space.runSizes`): a share of the run's span, and the run it was
/// given in, named by that zone's first member. A window planned in
/// any other zone, or in a run that would show everything at its
/// floors, plans at its floor and share (`RunZone`).
public struct RunSize: Sendable, Equatable, Codable {
    /// The window's length over the run's span, 0…1.
    public var share: CGFloat
    /// The first member of the zone the length was given in.
    public var zone: WindowID

    public init(share: CGFloat, zone: WindowID) {
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

extension [WindowID: RunSize] {
    /// Every entry re-pointed from `old` to `new`, as a key and as
    /// a zone — the re-key and the trade both take it.
    mutating func rename(_ old: WindowID, to new: WindowID) {
        if let size = removeValue(forKey: old) { self[new] = size }
        for (id, size) in self where size.zone == old {
            self[id] = RunSize(share: size.share, zone: new)
        }
    }
}
