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
/// integers at 20 windows across 3 arrangements, filed once per
/// arrangement change and carried in every session snapshot
/// (#1802).
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
    private var byArrangement: [Arrangement: [SpaceID: [WindowID]]] = [:]

    typealias Arrangement = HeldOrigin.Arrangement

    /// Whether applying `incoming` is a CHANGE — the one question
    /// that gates both the snapshot and the restore. A re-apply
    /// of the live arrangement (a monitor reconnect, an in-effect
    /// settings edit, a Standard recomposed for another screen
    /// count under its own name) must do neither: its remembered
    /// lists are older than the live ones, so restoring would
    /// revert the user's own moves.
    ///
    /// `live` is `KiwiCore.liveArrangement`, read from the
    /// adoption state — profiles.md ▸ "Whose arrangement is live"
    /// (#1249). A Standard is live as itself (#1829), so a
    /// Standard → profile apply is a switch like any other.
    func isSwitch(
        to incoming: Arrangement,
        from live: Arrangement?
    ) -> Bool {
        if let live { return live != incoming }
        // Nothing live: the session's first apply, or one after
        // the live profile was deleted or the #634 reset. The
        // first has nothing to replace — pruning there would drop
        // the Spaces the boot restore just rebuilt — and has no
        // record, which is what tells it from the others.
        return hasRecord(for: incoming)
    }

    /// Whether this arrangement has a partitioning to put back.
    func hasRecord(for profile: Arrangement) -> Bool {
        byArrangement[profile] != nil
    }

    /// Files the live Spaces under the arrangement they belong
    /// to. The lists are MEMBERSHIPS, not an order: the restore
    /// moves a window only when it sits elsewhere, appending the
    /// movers in this order after the members already in place
    /// (#1387).
    ///
    /// A nil `live` files nothing rather than being a caller's
    /// choice: nothing is live, so no partitioning is anyone's.
    mutating func record(_ spaces: [Space], as live: Arrangement?) {
        guard let live else { return }
        byArrangement[live] = Dictionary(
            uniqueKeysWithValues: spaces.map {
                ($0.id, $0.windows)
            }
        )
    }

    func remembered(
        for profile: Arrangement
    ) -> [SpaceID: [WindowID]]? {
        byArrangement[profile]
    }

    /// Every arrangement's record, for the session snapshot.
    var records: [Arrangement: [SpaceID: [WindowID]]] { byArrangement }

    /// Boot's adoption of the previous session's records (#1802):
    /// a carried entry replaces this session's for its key,
    /// since anything filed before the replay reflects the scan's
    /// order rather than the user's arrangement.
    mutating func adopt(
        _ records: [Arrangement: [SpaceID: [WindowID]]]
    ) {
        byArrangement.merge(records) { _, carried in carried }
    }

    /// A native-tab re-key (#308) moves the id in every record,
    /// not just the live one: a tab switched while B is up must
    /// still be found when A comes back.
    mutating func rekey(_ old: WindowID, to new: WindowID) {
        for (profile, spaces) in byArrangement {
            var updated = spaces
            for (space, windows) in spaces
            where windows.contains(old) {
                updated[space] = windows.map {
                    $0 == old ? new : $0
                }
            }
            byArrangement[profile] = updated
        }
    }

    /// A saved profile deleted — a Standard is never deleted.
    mutating func forget(_ profile: String) {
        byArrangement[.profile(profile)] = nil
    }

    mutating func rename(_ old: String, to new: String) {
        guard
            let entry = byArrangement.removeValue(forKey: .profile(old))
        else { return }
        byArrangement[.profile(new)] = entry
    }

    /// The #634 tier-1 discard: forgets every profile's
    /// arrangement. Which profile is live is not this store's to
    /// forget — that discard is not an adoption reset, and
    /// `ProfileManager.currentName` rightly survives it.
    mutating func forgetRecords() {
        byArrangement = [:]
    }
}
