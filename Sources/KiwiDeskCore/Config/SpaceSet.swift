import Foundation

/// A profile's Space arrangement on the live screens (#3294): what
/// the tour's replace of a preset writes, and what its Revert puts
/// back. Everything else in the profile — rules, layers, settings,
/// the look, Desktop bindings — is no part of it.
public struct SpaceSet: Sendable, Equatable {
    public let spaces: [SpaceID]
    public let spaceModes: [SpaceID: LayoutMode]
    /// The Spaces that take the Main role.
    public let mainSpaces: [SpaceID]
    /// Each pinned Space's screen number, as stored (#3647).
    public let pins: [SpaceID: ScreenSlotKey]
    public let fallbackSpace: SpaceID?

    public init(
        spaces: [SpaceID],
        spaceModes: [SpaceID: LayoutMode],
        mainSpaces: [SpaceID],
        pins: [SpaceID: ScreenSlotKey],
        fallbackSpace: SpaceID? = nil
    ) {
        self.spaces = spaces
        self.spaceModes = spaceModes
        self.mainSpaces = mainSpaces
        self.pins = pins
        self.fallbackSpace = fallbackSpace
    }
}

extension Profile {
    /// This profile's arrangement with all its pins, which belong to
    /// its numbers whatever screens are connected, so a Revert
    /// restores them all.
    func spaceSet() -> SpaceSet {
        SpaceSet(
            spaces: orderedSpaces,
            spaceModes: spaceModes,
            mainSpaces: mainSpaces,
            pins: spaceMonitorMap,
            fallbackSpace: fallbackSpace
        )
    }

    /// Replaces the arrangement, its pins included; a stored number
    /// `order` does not hold stays for a Space `set` keeps and does
    /// not pin (#3647 ▸ no-fit ruling).
    mutating func replaceSpaces(with set: SpaceSet, order: ScreenOrder) {
        let waiting = spaceMonitorMap.filter {
            !order.holds($0.value) && set.pins[$0.key] == nil
                && set.spaces.contains($0.key)
        }
        spaces = set.spaces
        spaceModes = set.spaceModes
        mainSpaces = set.mainSpaces
        fallbackSpace = set.fallbackSpace
        takePins(set.pins.merging(waiting) { own, _ in own })
    }
}
