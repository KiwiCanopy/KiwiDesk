import Foundation

/// What each arrangement left behind: per saved profile and per
/// composed Standard (#1829), the windows each of its Spaces held
/// when it was last live (#1230).
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
/// This is a store, and #1230 refused one for the DESKTOP axis.
/// The discriminator is WHEN the record is authoritative: this
/// one is written as a profile goes inactive and read as it comes
/// back, so it and live truth are never both authoritative and
/// cannot disagree. The refused one would have been read while
/// the compositor was still moving what it copied. See
/// `KiwiCore+DesktopSpaces.swift` for that argument in full.
///
/// Window ids only, never window state (#1230 ruling 4): ~60
/// integers at 20 windows across 3 profiles, filed once per
/// profile change and carried in every session snapshot (#1802).
/// Entries are NOT pruned on a window's
/// disappearance — an away Desktop's windows are absent from
/// `state.windows` too (#1146), so pruning on absence would make
/// a Desktop return lose its profile memory. A restore filters to
/// live windows instead, and the enders are explicit: a profile
/// deleted, a profile renamed, the #634 reset, and a profile
/// absent from disk when boot adopts the carried records.
struct ProfilePartitioning: Sendable {
    /// Keyed by ARRANGEMENT — a saved profile or a composed
    /// Standard (#1829), which may share a name (`Starter`).
    private var byProfile: [Arrangement: [SpaceID: [WindowID]]] = [:]

    typealias Arrangement = HeldOrigin.Arrangement

    /// Whether applying `profile` is a CHANGE — the one question
    /// that gates both the snapshot and the restore. A re-apply
    /// of the live profile (a monitor reconnect, an in-effect
    /// settings edit) must do neither: its remembered lists are
    /// older than the live ones, so restoring would revert the
    /// user's own moves.
    ///
    /// `live` is `ProfileManager.currentName`, the one authority
    /// for whose arrangement is on screen — profiles.md ▸ "Whose
    /// arrangement is live" (#1249).
    func isSwitch(
        to profile: Arrangement,
        from live: Arrangement?
    ) -> Bool {
        if let live { return live != profile }
        // No live profile means one of two things, and they must
        // not be conflated. The session's FIRST apply has nothing
        // to replace — pruning there would drop the Spaces the
        // boot restore just rebuilt. A Standard handing the slot
        // back is the other, and there the incoming profile has a
        // record to put back, which is what tells them apart.
        return hasRecord(for: profile)
    }

    /// Whether this profile has an arrangement to put back. A
    /// built-in Standard hands the live slot back as nil, so
    /// "no live profile" must not read as "not a switch" — the
    /// apply after a Standard would otherwise skip the restore
    /// and fall back to the pre-#1230 name-match for that one
    /// apply.
    func hasRecord(for profile: Arrangement) -> Bool {
        byProfile[profile] != nil
    }

    /// Files the live Spaces under the profile they belong to. The
    /// lists are MEMBERSHIPS, not an order: the restore moves a
    /// window only when it sits elsewhere, appending the movers in
    /// this order after the members already in place (#1387).
    ///
    /// A nil `live` files nothing rather than being a caller's
    /// choice: boot and a built-in Standard have no profile whose
    /// partitioning this is.
    mutating func record(_ spaces: [Space], as live: Arrangement?) {
        guard let live else { return }
        byProfile[live] = Dictionary(
            uniqueKeysWithValues: spaces.map {
                ($0.id, $0.windows)
            }
        )
    }

    func remembered(
        for profile: Arrangement
    ) -> [SpaceID: [WindowID]]? {
        byProfile[profile]
    }

    /// Every profile's record, for the session snapshot (#1802).
    var records: [Arrangement: [SpaceID: [WindowID]]] { byProfile }

    /// Boot's adoption of the previous session's records (#1802):
    /// a carried entry replaces this session's for that profile,
    /// since anything filed before the replay reflects the scan's
    /// order rather than the user's arrangement.
    mutating func adopt(
        _ records: [Arrangement: [SpaceID: [WindowID]]]
    ) {
        byProfile.merge(records) { _, carried in carried }
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

    /// A saved profile deleted — a Standard is never deleted.
    mutating func forget(_ profile: String) {
        byProfile[.profile(profile)] = nil
    }

    mutating func rename(_ old: String, to new: String) {
        guard
            let entry = byProfile.removeValue(forKey: .profile(old))
        else { return }
        byProfile[.profile(new)] = entry
    }

    /// The #634 tier-1 discard: forgets every profile's
    /// arrangement. Which profile is live is not this store's to
    /// forget — that discard is not an adoption reset, and
    /// `ProfileManager.currentName` rightly survives it.
    mutating func forgetRecords() {
        byProfile = [:]
    }
}
