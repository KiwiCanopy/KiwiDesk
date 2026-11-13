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
    /// Each pinned Space's screen fingerprint, on the live screens.
    public let pins: [SpaceID: String]
    public let fallbackSpace: SpaceID?

    public init(
        spaces: [SpaceID],
        spaceModes: [SpaceID: LayoutMode],
        mainSpaces: [SpaceID],
        pins: [SpaceID: String],
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
    /// This profile's arrangement on the set covering `monitors`.
    func spaceSet(monitors: [String]) -> SpaceSet {
        SpaceSet(
            spaces: orderedSpaces,
            spaceModes: spaceModes,
            mainSpaces: mainSpaces,
            pins: set(matching: monitors)?.spaceMonitorMap ?? [:],
            fallbackSpace: fallbackSpace
        )
    }

    /// Replaces the arrangement: the live set's pins become `set`'s,
    /// and every other set drops pins to a Space no longer declared.
    mutating func replaceSpaces(with set: SpaceSet, monitors: [String]) {
        spaces = set.spaces
        spaceModes = set.spaceModes
        mainSpaces = set.mainSpaces
        fallbackSpace = set.fallbackSpace
        let kept = Set(set.spaces)
        let live = self.set(matching: monitors)?.monitors
        for stored in monitorSets {
            let map =
                stored.monitors == live
                ? set.pins
                : stored.spaceMonitorMap.filter { kept.contains($0.key) }
            upsert(
                MonitorSet(monitors: stored.monitors, spaceMonitorMap: map)
            )
        }
    }
}
