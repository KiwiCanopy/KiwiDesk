import Foundation

/// The doors through which a profile claims a monitor combination
/// (#1530): a save or create of the live arrangement, a load, and
/// the Profiles page's pick. Boot and monitor-change matching
/// never claim.
extension KiwiCore {
    /// The connected monitors' fingerprints.
    var liveFingerprints: [String] {
        state.workspaces.allDisplays.map(\.fingerprint)
    }

    /// Strips the connected combination from every other profile
    /// of its count when `profile` holds it — `saveProfile`'s tail.
    func claimLiveSet(heldBy profile: Profile) throws -> [String] {
        let live = liveFingerprints
        guard !live.isEmpty, profile.set(matching: live) != nil
        else { return [] }
        return try profiles.claim(live, for: profile.name)
    }

    /// Loads `name` explicitly — `load_profile`, Switch Profile —
    /// and, where its screen count fits, adds the connected
    /// combination to it and strips it from the others first, so
    /// the load sticks at the next monitor change. A profile for
    /// another count loads dirty, claiming nothing (#36). Returns
    /// the profiles that lost the combination.
    @discardableResult
    public func loadProfile(named name: String) throws -> [String] {
        var profile = try profiles.read(name: name)
        let live = liveFingerprints
        var released: [String] = []
        if !live.isEmpty, profile.monitorCount == live.count {
            if profile.set(matching: live) == nil {
                profile.upsert(MonitorSet(monitors: live))
                try profiles.write(profile)
            }
            released = try profiles.claim(live, for: name)
        }
        // Explicit user load: the profile's spaces become
        // authoritative — stale spaces are pruned and their
        // windows forwarded (see `pruneSpaces`).
        apply(
            profile: profile,
            pruneStaleSpaces: true,
            forceRetile: true
        )
        return released
    }

    /// Gives the combination `monitors` to `name` — the Profiles
    /// page's pick, stripped from its previous owner without a
    /// warning (ruled). Pins travel from that owner for the Spaces
    /// `name` declares. Live state is untouched: the pick decides
    /// the next match, not what is on screen. Returns the profiles
    /// that lost it.
    @discardableResult
    public func claimMonitorSet(
        _ monitors: [String],
        for name: String
    ) throws -> [String] {
        var profile = try profiles.read(name: name)
        guard monitors.count == profile.monitorCount else {
            throw ProfileSaveError.screenCountMismatch(
                expected: profile.monitorCount,
                live: monitors.count
            )
        }
        if profile.set(matching: monitors) == nil {
            let declared = profile.declaredSpaces
            let previous =
                profiles.allProfiles().lazy
                .compactMap { $0.set(matching: monitors) }
                .first?.spaceMonitorMap ?? [:]
            profile.upsert(
                MonitorSet(
                    monitors: monitors,
                    spaceMonitorMap: previous.filter {
                        declared.contains($0.key)
                    }
                )
            )
            try profiles.write(profile)
        }
        return try profiles.claim(monitors, for: name)
    }

    /// The combinations `name` could claim: every set a profile of
    /// its screen count holds, plus the connected one where it fits,
    /// each once, sorted (#1530).
    public func claimableMonitorSets(for name: String) -> [[String]] {
        guard let profile = try? profiles.read(name: name)
        else { return [] }
        let count = profile.monitorCount
        var sets = Set(
            profiles.allProfiles()
                .filter { $0.monitorCount == count }
                .flatMap { $0.monitorSets.map(\.monitors) }
        )
        let live = liveFingerprints.sorted()
        if live.count == count { sets.insert(live) }
        return sets.sorted { $0.joined() < $1.joined() }
    }

    /// The `save_profile` / `load_profile` answer: plain `ok`, or
    /// the profiles that lost the connected combination and why,
    /// so a scripted save is not a silent change to another file.
    /// English — a machine contract (core-boundaries.md).
    static func claimResponse(
        _ released: [String],
        claimant: String
    ) -> CommandResponse {
        guard !released.isEmpty else { return .ok() }
        return .ok(
            .object([
                "takenFrom": .array(released.map { .string($0) }),
                "reason": .string(
                    "The connected screen combination now "
                        + "belongs to '\(claimant)'; a combination "
                        + "belongs to one profile."
                ),
            ])
        )
    }
}
