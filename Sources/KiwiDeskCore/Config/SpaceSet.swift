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
    /// Every monitor set's pins, where a Revert puts the whole
    /// profile's back; nil for a replace, which writes the live
    /// set's and drops the others' pins to a dropped Space.
    let monitorSets: [MonitorSet]?

    public init(
        spaces: [SpaceID],
        spaceModes: [SpaceID: LayoutMode],
        mainSpaces: [SpaceID],
        pins: [SpaceID: String],
        fallbackSpace: SpaceID? = nil
    ) {
        self.init(
            spaces: spaces,
            spaceModes: spaceModes,
            mainSpaces: mainSpaces,
            pins: pins,
            fallbackSpace: fallbackSpace,
            monitorSets: nil
        )
    }

    init(
        spaces: [SpaceID],
        spaceModes: [SpaceID: LayoutMode],
        mainSpaces: [SpaceID],
        pins: [SpaceID: String],
        fallbackSpace: SpaceID?,
        monitorSets: [MonitorSet]?
    ) {
        self.spaces = spaces
        self.spaceModes = spaceModes
        self.mainSpaces = mainSpaces
        self.pins = pins
        self.fallbackSpace = fallbackSpace
        self.monitorSets = monitorSets
    }
}

extension Profile {
    /// This profile's arrangement on the set covering `monitors`,
    /// carrying every set's pins so a Revert restores them all.
    func spaceSet(monitors: [String]) -> SpaceSet {
        SpaceSet(
            spaces: orderedSpaces,
            spaceModes: spaceModes,
            mainSpaces: mainSpaces,
            pins: set(matching: monitors)?.spaceMonitorMap ?? [:],
            fallbackSpace: fallbackSpace,
            monitorSets: monitorSets
        )
    }

    /// Replaces the arrangement: the live set's pins become `set`'s,
    /// and every other set drops pins to a Space no longer declared
    /// — or, for a Revert, every set takes back the pins it had.
    mutating func replaceSpaces(with set: SpaceSet, monitors: [String]) {
        spaces = set.spaces
        spaceModes = set.spaceModes
        mainSpaces = set.mainSpaces
        fallbackSpace = set.fallbackSpace
        if let stored = set.monitorSets {
            for monitorSet in stored { upsert(monitorSet) }
            return
        }
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
