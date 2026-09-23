import Foundation

/// A monitor set another profile could take (#1530): its
/// monitors, the profile holding it now, and whether it is the
/// connected one.
public struct ClaimableMonitorSet: Equatable, Sendable {
    public let monitors: [String]
    public let owner: String?
    public let isConnected: Bool
}

/// The doors through which a profile claims a monitor set
/// (#1530): a save or create of the live arrangement, a load, and
/// the Profiles page's pick. Boot, monitor-change matching and a
/// Desktop binding's load never claim.
extension KiwiCore {
    /// The connected monitors' fingerprints — the one reading of
    /// the live set every profile door takes.
    var liveFingerprints: [String] {
        state.workspaces.allDisplays.map(\.fingerprint)
    }

    /// The live Space→monitor pins, read-only — what a pick onto
    /// the loaded profile leaves live, for the draft to follow.
    public var livePins: [SpaceID: String] { spacePins }

    /// Whether `monitors` is the connected set — the one answer
    /// the Profiles page and the pick both take (#1530).
    public func isConnectedMonitorSet(_ monitors: [String]) -> Bool {
        !monitors.isEmpty
            && MonitorSet(monitors: monitors).monitors
                == MonitorSet(monitors: liveFingerprints).monitors
    }

    /// Strips the connected set from every other profile of its
    /// count when `profile` holds it — `saveProfile`'s tail.
    func claimLiveSet(heldBy profile: Profile) throws -> [String] {
        let live = liveFingerprints
        guard !live.isEmpty, profile.set(matching: live) != nil
        else { return [] }
        return try profiles.claim(live, for: profile.name)
    }

    /// Hands `monitors` to `profile` — the load's and the pick's
    /// one hand-over. A set the profile does not hold yet arrives
    /// with its current owner's pins for the Spaces `profile`
    /// declares, so a round trip keeps those both declare.
    private func handOver(
        _ monitors: [String],
        to profile: inout Profile
    ) throws -> [String] {
        if profile.set(matching: monitors) == nil {
            let declared = profile.declaredSpaces
            let pins =
                profiles.allProfiles()
                .first { $0.set(matching: monitors) != nil }?
                .set(matching: monitors)?.spaceMonitorMap ?? [:]
            profile.upsert(
                MonitorSet(
                    monitors: monitors,
                    spaceMonitorMap: pins.filter {
                        declared.contains($0.key)
                    }
                )
            )
            try profiles.write(profile)
        }
        return try profiles.claim(monitors, for: profile.name)
    }

    /// Loads `name` explicitly — `load_profile`, Switch Profile —
    /// and, where its screen count fits, hands it the connected
    /// set first, so the load sticks at the next monitor change. A
    /// profile for another count loads dirty, claiming nothing
    /// (#36). Returns the profiles that lost the set.
    @discardableResult
    public func loadProfile(named name: String) throws -> [String] {
        var profile = try profiles.read(name: name)
        let live = liveFingerprints
        var released: [String] = []
        if !live.isEmpty, profile.monitorCount == live.count {
            released = try handOver(live, to: &profile)
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

    /// Gives `monitors` to `name` — the Profiles page's pick,
    /// taken from its previous owner without a warning (ruled).
    /// Returns the profiles that lost it.
    ///
    /// No apply runs, so where the pick is the CONNECTED set the
    /// live profile's #36 fit is re-judged here: it fits exactly
    /// when it is the claimant (profiles.md ▸ "Let the apply judge
    /// the #36 fit" — a caller whose verdict differs says why), and
    /// then adopts the set's pins as the monitor-change exact arm
    /// does, or its next save would overwrite them with live's.
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
        let released = try handOver(monitors, to: &profile)
        if isConnectedMonitorSet(monitors),
            let current = profiles.currentName
        {
            if current == name {
                spacePins =
                    profile.set(matching: monitors)?.spaceMonitorMap
                    ?? [:]
                resolveSpaceDisplays()
                retile()
                emitSpaceChange()
                profiles.markClean()
            } else if released.contains(current) {
                profiles.markDirty()
            }
        }
        return released
    }

    /// The sets `name` could take: every set a profile of its
    /// screen count holds, plus the connected one where it fits,
    /// minus its own — the connected one first, then by owner.
    public func claimableMonitorSets(
        for name: String
    ) -> [ClaimableMonitorSet] {
        guard let profile = try? profiles.read(name: name)
        else { return [] }
        let count = profile.monitorCount
        let peers = profiles.allProfiles().filter {
            $0.monitorCount == count
        }
        var sets = Set(peers.flatMap { $0.monitorSets.map(\.monitors) })
        let live = MonitorSet(monitors: liveFingerprints).monitors
        if live.count == count { sets.insert(live) }
        let own = Set(profile.monitorSets.map(\.monitors))
        return sets.subtracting(own)
            .map { monitors in
                ClaimableMonitorSet(
                    monitors: monitors,
                    owner: peers.first {
                        $0.set(matching: monitors) != nil
                    }?.name,
                    isConnected: isConnectedMonitorSet(monitors)
                )
            }
            .sorted {
                if $0.isConnected != $1.isConnected {
                    return $0.isConnected
                }
                return ($0.owner ?? "", $0.monitors.joined())
                    < ($1.owner ?? "", $1.monitors.joined())
            }
    }

    /// The one-time settle of sets several profiles held before
    /// #1530 — each stays with the profile that loads it today.
    /// Called at the format crossing (`loadConfig`) and after a
    /// restore, whose files may predate the rule; never per boot.
    func settleSharedSets() {
        do {
            for line in try profiles.settleSharedSets() {
                onLog(line)
            }
        } catch {
            onLog("profiles: settling shared monitor sets failed: \(error)")
        }
    }

    /// The `save_profile` / `load_profile` answer: plain `ok`, or
    /// the profiles that lost the connected set and why, so a
    /// scripted save is not a silent change to another file.
    /// English — a machine contract (core-boundaries.md).
    static func claimResponse(
        _ released: [String],
        claimant: String
    ) -> CommandResponse {
        guard !released.isEmpty else { return .ok() }
        return .ok(
            .object([
                "taken_from": .array(released.map { .string($0) }),
                "reason": .string(
                    "The connected monitor set now belongs to "
                        + "'\(claimant)'; a monitor set belongs to "
                        + "one profile."
                ),
            ])
        )
    }
}
