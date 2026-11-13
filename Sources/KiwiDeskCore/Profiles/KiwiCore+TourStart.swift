import Foundation

/// The tour's "Start with" choice (#3294, owner rulings 2026-11-13):
/// which offered layout the live desk still is, and the Continue that
/// makes a pick live. Saved on Continue, never on a click.
extension KiwiCore {
    /// The offered layout the live profile still is, untouched —
    /// the same Spaces, layouts, Main role and pins on these screens
    /// — or nil where the desk changed and a pick would replace it.
    public func untouchedTourChoice(
        among offered: [StandardLayout]
    ) -> StandardLayout? {
        guard let name = profiles.currentName,
            let profile = try? profiles.read(name: name)
        else { return nil }
        let live = profile.spaceSet(monitors: liveFingerprints)
        return offered.first { layout in
            guard let planned = spaceSet(for: layout),
                Self.sameArrangement(planned, live)
            else { return false }
            return layout.starterTitle != nil
                ? profile.isStarterSetup
                : isPresetCopy(name, of: layout)
        }
    }

    /// The Continue on an untouched desk: `layout` becomes live —
    /// the starter's own profile where it is the starter, else a
    /// fresh copy of the preset — and the untouched preset copy it
    /// replaces is deleted, so copies never pile up. Returns the
    /// name now live.
    @discardableResult
    public func startTour(
        with layout: StandardLayout,
        replacing untouched: StandardLayout?
    ) throws -> String {
        let left = profiles.currentName
        let leftCopy = untouched.flatMap { choice in
            choice.starterTitle == nil ? left : nil
        }
        if layout.starterTitle != nil, let starter = starterProfileName() {
            try loadProfile(named: starter)
        } else {
            try applyStandard(layout)
        }
        if let leftCopy, leftCopy != profiles.currentName {
            _ = execute("delete_profile", args: [.string(leftCopy)])
        }
        return profiles.currentName ?? ""
    }

    /// The saved starter profile for the connected screen count.
    func starterProfileName() -> String? {
        let count = liveFingerprints.count
        return profiles.allProfiles().first {
            $0.isStarterSetup && $0.monitorCount == count
        }?.name
    }

    /// Whether `name` is the name a preset copy of `layout` takes:
    /// the preset's own name, or it with a free-name suffix.
    func isPresetCopy(_ name: String, of layout: StandardLayout) -> Bool {
        let base = layout.name.lowercased()
        let lowered = name.lowercased()
        guard lowered != base else { return true }
        guard lowered.hasPrefix(base + "_") else { return false }
        return Int(lowered.dropFirst(base.count + 1)) != nil
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
