import Foundation

/// What each profile left behind: per profile name, the windows
/// each of its Spaces held when that profile was last live
/// (#1230).
///
/// **The profile is the SCOPE a Space name resolves in.** A
/// Space's name stays its identity — `focus_space 1`, app rules,
/// keybindings and every stored key keep the string — but two
/// profiles may each declare a `1` or a `Work` and they are
/// different Spaces. Without this record they were the same one:
/// `apply(profile:)` name-matched through `ensureSpace`, so
/// switching profiles and back merged an arrangement away
/// permanently (measured 2026-09-04; `ProfilePartitioningTests`
/// is that measurement).
///
/// This is a store, and #1230 refused one for the DESKTOP axis on
/// the ground that a window's Desktop is the WindowServer's fact
/// and a copy of it can de-sync. The profile axis is the
/// opposite case: which KiwiDesk Space a window sat in under
/// profile A is a fact nothing outside KiwiDesk has an opinion
/// about, so there is no second source of truth to disagree with.
/// See `KiwiCore+DesktopSpaces.swift` for the axis that must
/// never be stored.
///
/// Window ids only, never window state (#1230 ruling 4): ~60
/// integers at 20 windows across 3 profiles, written once per
/// profile change. Entries are NOT pruned on a window's
/// disappearance — an away Desktop's windows are absent from
/// `state.windows` too (#1146), so pruning on absence would make
/// a Desktop return lose its profile memory. A restore filters to
/// live windows instead, and the enders are explicit: a profile
/// deleted, a profile renamed, and the #634 reset.
struct ProfilePartitioning: Sendable {
    /// The profile whose partitioning the LIVE Spaces currently
    /// represent.
    ///
    /// Tracked here rather than read from
    /// `ProfileManager.currentName`, which cannot answer it:
    /// `profiles.load(name:)` sets `currentName` to the INCOMING
    /// profile before `apply(profile:)` runs, so by the time the
    /// snapshot is due the outgoing name is already gone.
    private(set) var liveProfile: String?

    private var byProfile: [String: [SpaceID: [WindowID]]] = [:]

    /// Whether applying `profile` is a CHANGE — the one question
    /// that gates both the snapshot and the restore. A re-apply
    /// of the live profile (a monitor reconnect, an in-effect
    /// settings edit) must do neither: its remembered lists are
    /// older than the live ones, so restoring would revert the
    /// user's own moves.
    func isSwitch(to profile: String) -> Bool {
        liveProfile != nil && liveProfile != profile
    }

    /// Files the live Spaces under the profile they belong to and
    /// hands the live slot to `next`. Order IS the rank: the
    /// restore re-adds in this order.
    mutating func record(
        _ spaces: [Space],
        handingLiveTo next: String?
    ) {
        if let live = liveProfile {
            byProfile[live] = Dictionary(
                uniqueKeysWithValues: spaces.map {
                    ($0.id, $0.windows)
                }
            )
        }
        liveProfile = next
    }

    /// Seeds the live slot without recording anything — boot, and
    /// the first profile of a session, have no outgoing
    /// partitioning to file.
    mutating func adoptLive(_ profile: String?) {
        liveProfile = profile
    }

    func remembered(
        for profile: String
    ) -> [SpaceID: [WindowID]]? {
        byProfile[profile]
    }

    /// A native-tab re-key (#308) moves the id in every profile's
    /// record, not just the live one: a tab switched while
    /// profile B is up must still be found when A comes back.
    mutating func rekey(_ old: WindowID, to new: WindowID) {
        for (profile, spaces) in byProfile {
            var updated = spaces
            for (space, windows) in spaces
            where windows.contains(old) {
                updated[space] = windows.map {
                    $0 == old ? new : $0
                }
            }
            byProfile[profile] = updated
        }
    }

    mutating func forget(_ profile: String) {
        byProfile[profile] = nil
        if liveProfile == profile { liveProfile = nil }
    }

    mutating func rename(_ old: String, to new: String) {
        guard let entry = byProfile.removeValue(forKey: old)
        else {
            if liveProfile == old { liveProfile = new }
            return
        }
        byProfile[new] = entry
        if liveProfile == old { liveProfile = new }
    }

    /// Reset All Settings (#634).
    mutating func reset() {
        byProfile = [:]
        liveProfile = nil
    }
}
