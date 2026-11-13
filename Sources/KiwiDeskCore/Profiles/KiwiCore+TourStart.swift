import Foundation

/// The tour's "Start with" choice (#3294, owner rulings 2026-11-13):
/// what the live desk is to the Spaces step, and the Continue that
/// makes a pick live. Saved on Continue, never on a click.
extension KiwiCore {
    /// A preset copy this tour presentation saved, as written: the
    /// one profile a later pick may delete, and only while its file
    /// still reads exactly so — nothing of the user's is in it.
    public struct TourCopy: Equatable, Sendable {
        let layout: String
        let profile: Profile
    }

    /// What the live desk is to the Spaces step.
    public enum TourDesk: Equatable, Sendable {
        /// The offered layout the desk still is, untouched.
        case untouched(StandardLayout)
        /// No saved profile of these screens is live, so a pick
        /// starts a profile of its own and replaces nothing.
        case unsaved
        /// The user's own Spaces, which a pick replaces in place.
        case changed
    }

    /// Reads the desk against `offered`. A preset counts as
    /// untouched only as `copy`, the copy this presentation saved;
    /// the starter as the starter profile on its own arrangement.
    public func tourDesk(
        among offered: [StandardLayout],
        copy: TourCopy?
    ) -> TourDesk {
        guard let name = profiles.currentName,
            let profile = try? profiles.read(name: name),
            profile.set(matching: liveFingerprints) != nil
        else { return .unsaved }
        if let copy, copy.profile == profile,
            let layout = offered.first(where: { $0.name == copy.layout })
        {
            return .untouched(layout)
        }
        let live = profile.spaceSet(monitors: liveFingerprints)
        if profile.isStarterSetup,
            let starter = offered.first(where: { $0.starterTitle != nil }),
            let planned = spaceSet(for: starter),
            Self.sameArrangement(planned, live)
        {
            return .untouched(starter)
        }
        return .changed
    }

    /// The Continue where nothing of the user's is replaced:
    /// `layout` becomes live — the starter's own profile where it
    /// is the starter, else a fresh preset copy, returned — and
    /// `copy`, the untouched copy it replaces, is deleted, so copies
    /// never pile up.
    @discardableResult
    public func startTour(
        with layout: StandardLayout,
        replacing copy: TourCopy?
    ) throws -> TourCopy? {
        let left = copy?.profile.name
        var made: TourCopy?
        if layout.starterTitle != nil, let starter = starterProfileName() {
            try loadProfile(named: starter)
        } else {
            let name = try applyStandard(layout)
            made = (try? profiles.read(name: name)).map {
                TourCopy(layout: layout.name, profile: $0)
            }
        }
        if let left, left != profiles.currentName {
            let deleted = execute("delete_profile", args: [.string(left)])
            if !deleted.isSuccess {
                onLog(
                    "tour: the replaced copy \(left) stays: "
                        + (deleted.error ?? deleted.status)
                )
            }
        }
        return made
    }

    /// The saved starter profile for the connected screen count.
    func starterProfileName() -> String? {
        let count = liveFingerprints.count
        return profiles.allProfiles().first {
            $0.isStarterSetup && $0.monitorCount == count
        }?.name
    }

    /// Two arrangements alike on screen: Spaces in order, each one's
    /// layout (`bsp` where unstated), the Main role and the pins.
    static func sameArrangement(_ lhs: SpaceSet, _ rhs: SpaceSet) -> Bool {
        let modes = { (set: SpaceSet) in
            set.spaces.map { set.spaceModes[$0] ?? .bsp }
        }
        return lhs.spaces == rhs.spaces && modes(lhs) == modes(rhs)
            && Set(lhs.mainSpaces) == Set(rhs.mainSpaces)
            && lhs.pins == rhs.pins
    }
}
