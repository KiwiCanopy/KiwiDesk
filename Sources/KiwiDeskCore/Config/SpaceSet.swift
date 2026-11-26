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
    /// This profile's arrangement where a set covers `monitors`,
    /// its pins all of them, so a Revert restores them all; no pins
    /// where no set covers the screens.
    func spaceSet(monitors: [String]) -> SpaceSet {
        SpaceSet(
            spaces: orderedSpaces,
            spaceModes: spaceModes,
            mainSpaces: mainSpaces,
            pins: set(matching: monitors) == nil ? [:] : spaceMonitorMap,
            fallbackSpace: fallbackSpace
        )
    }

    /// Replaces the arrangement, its pins included.
    mutating func replaceSpaces(with set: SpaceSet) {
        spaces = set.spaces
        spaceModes = set.spaceModes
        mainSpaces = set.mainSpaces
        fallbackSpace = set.fallbackSpace
        spaceMonitorMap = set.pins
    }
}
