import Foundation

/// The PROFILE axis of #1230 — the one door onto "whose Spaces
/// are live, and what did the last profile leave behind".
/// `ProfileSpacesSeamTests` pins that `profilePartitioning` is
/// reached only from here and its four enders.
///
/// The Desktop axis is `KiwiCore+DesktopSpaces.swift`, which
/// carries the argument for why one is stored and the other
/// never is — the discriminator being WHEN a record is
/// authoritative. Different subjects that merely rhyme: folding
/// them would give the stored half the unstored half's
/// lifetime.
extension KiwiCore {
    /// Files the live Spaces under the live arrangement — the
    /// saved profile `profiles.currentName` names, or the composed
    /// Standard (#1829) — so every verb that moves it files first
    /// and moves second — profiles.md ▸ "Whose arrangement is
    /// live" (#1249). A session that has applied nothing files
    /// nothing.
    func recordLivePartitioning() {
        state.profilePartitioning.record(
            livePartitioning,
            as: liveArrangement
        )
    }

    private var livePartitioning: [Space] {
        capturedSpaces.map {
            Space(
                id: $0.id,
                windows: withAwayMembers($0.windows, of: $0.id)
            )
        }
    }

    /// Every arrangement's record for the session snapshot
    /// (#1802, #1829), the live one filed fresh — on a copy, since
    /// the live record is written only as it goes inactive. A
    /// relaunch under ANOTHER arrangement then still knows the one
    /// live at the quit.
    func partitioningForSnapshot() -> StateSnapshot.ArrangementRecords? {
        var carried = state.profilePartitioning
        carried.record(livePartitioning, as: liveArrangement)
        let records = carried.records
        return records.isEmpty ? nil : .init(records)
    }

    /// Boot adopts the previous session's records after the
    /// replay (#1802) — after the boot apply too, which must not
    /// read a carried record as a switch and prune. A record for
    /// a profile no longer on disk is dropped: it could never be
    /// restored, and a new profile of that name is not it. An
    /// empty listing is not proof — an unreadable directory lists
    /// empty too — so it drops nothing, and a Standard's record is
    /// always kept, since a built-in cannot be deleted (#1829).
    func adoptCarriedPartitioning(from session: StateSnapshot) {
        guard let carried = session.arrangementRecords?.records,
            !carried.isEmpty
        else { return }
        let saved = Set(profiles.list())
        let kept = carried.filter { arrangement, _ in
            guard case .profile(let name) = arrangement,
                !saved.isEmpty
            else { return true }
            return saved.contains(name)
        }
        state.profilePartitioning.adopt(kept)
        onLog(
            "restore: carried the Space records of "
                + "\(kept.count) arrangement(s)"
        )
    }

    /// Files the outgoing arrangement's partitioning before the
    /// space set is rebuilt. Returns whether this apply is a
    /// CHANGE, so the caller gates the prune and the restore on
    /// one answer.
    ///
    /// A re-apply of the LIVE arrangement, or the session's
    /// first, files nothing and restores nothing — neither a
    /// monitor reconnect nor boot may revert what is on screen.
    ///
    /// `apply(profile:)` gates the session-ratio clear, the hold,
    /// the prune and the restore on the answer; `apply(composed:)`
    /// gates only the restore. A Standard is transient (#53): it
    /// prunes nothing, holds nothing and keeps the session layer,
    /// so the outgoing profile's undeclared Spaces stay live beside
    /// it and the restore moves windows into its DECLARED Spaces
    /// alone. A step that must follow an arrangement change on
    /// both doors — #1790's temporary-Space drop — gates on this
    /// same answer, never a test of its own.
    func recordOutgoingPartitioning(
        before incoming: HeldOrigin.Arrangement
    ) -> Bool {
        guard
            state.profilePartitioning.isSwitch(
                to: incoming,
                from: liveArrangement
            )
        else { return false }
        recordLivePartitioning()
        return true
    }

    /// A saved profile's entry to the two calls around it.
    func recordOutgoingPartitioning(before profile: Profile) -> Bool {
        recordOutgoingPartitioning(before: .profile(profile.name))
    }

    func restoreProfilePartitioning(of profile: Profile) {
        restorePartitioning(
            of: .profile(profile.name),
            declaring: profile.declaredSpaces
        )
    }

    /// The one profile WRITE door (#1249). `ProfileManager.save`
    /// makes its argument current, so the outgoing name is gone
    /// the moment it returns; the filing has to precede it.
    ///
    /// Unconditional rather than a caller's choice: saving a live
    /// Standard files it under the Standard, whose arrangement is
    /// going inactive, so no exit has anything to decide.
    ///
    /// The saved profile claims the connected combination it now
    /// holds (#1530); returns the profiles that lost it.
    @discardableResult
    func saveProfile(_ profile: Profile) throws -> [String] {
        recordLivePartitioning()
        try profiles.save(profile)
        return try claimLiveSet(heldBy: profile)
    }

    /// Forwards every window of `space` into `fallback` and drops
    /// the Space — membership, the display-crossing re-anchor
    /// (#444) and the re-file record (#1177) in one step. The ONE
    /// forwarding primitive: the prune and `delete_space` both
    /// take it (`SpaceForwardingSeamTests`), since a hand copy of
    /// the step list is how the record went missing from one.
    func forwardWindows(of space: SpaceID, to fallback: SpaceID) {
        for window in state.workspaces[space]?.windows ?? [] {
            state.workspaces.add(window, to: fallback)
            // A later `resolveSpaceDisplays` moving the fallback
            // re-translates from the seeded capture, so the order
            // composes.
            reanchorFloat(window, to: fallback)
            refiledWindows.insert(window)
        }
        state.workspaces.removeSpace(space)
    }

    /// Puts the incoming profile's own windows back in its own
    /// Spaces.
    ///
    /// Runs AFTER the prune, so the order is the landing rule
    /// (#1230, owner 2026-09-03): the prune has already forwarded
    /// everything the new profile does not declare into its
    /// `fallback_space`, and this moves back only what that
    /// profile remembers. A window it has never seen — opened
    /// while another profile was up — therefore stays where the
    /// prune put it, which is the existing setting for exactly
    /// this situation and needs no new concept.
    ///
    /// Only LIVE windows MOVE: a remembered id can belong to a
    /// window since closed, or to one sitting on an away Desktop
    /// (#1146), and inserting either would put a phantom in the
    /// row. Those take the other half — their remembered Space is
    /// re-filed to this profile's, since it is what places them
    /// if they come back and it answers once across every profile
    /// (#1248, `refileAway`).
    ///
    /// A remembered Space the profile no longer declares is
    /// skipped rather than re-created: the prune just dropped it,
    /// and `WorkspaceManager.add` would silently `ensureSpace` it
    /// back into a set the profile is authoritative over.
    ///
    /// A window ALREADY in its remembered Space is left where it
    /// sits: the record is a membership, the live row the order
    /// authority (#1387, profiles.md).
    ///
    /// A window in a held Space, live or remembered there, is left
    /// too: any hold outranks this record, so what was on a gone
    /// screen stays together and goes home together (#1728).
    func restorePartitioning(
        of arrangement: HeldOrigin.Arrangement,
        declaring declared: Set<SpaceID>
    ) {
        guard
            let remembered = state.profilePartitioning.remembered(
                for: arrangement
            )
        else { return }
        // `WorkspaceManager.add` calls `remove` first, which nils
        // both focus trackers when the moved window holds them
        // (`moveWindow` re-establishes focus for exactly this
        // reason). Restoring the profile's arrangement must not
        // cost the focus ring its anchor or destroy the one-deep
        // close-return candidate (bars.md, borders.md), so they
        // are captured and re-asserted around the moves.
        let heldFocus = state.workspaces.lastFocused
        let heldCandidate = state.workspaces.focusReturnCandidate
        var heldSpaceFocus: [SpaceID: WindowID] = [:]
        for space in state.workspaces.allSpaces {
            heldSpaceFocus[space.id] = space.focused
        }
        var moved = 0
        var refiled = 0
        for space in SpaceID.numericLexicalSorted(
            Array(remembered.keys)
        ) {
            guard declared.contains(space),
                state.workspaces[space] != nil
            else { continue }
            for window in remembered[space] ?? [] {
                guard heldSpace(holding: window) == nil else { continue }
                guard state.windows[window] != nil else {
                    // Not in state: away on another Desktop, or
                    // closed and still remembered (a close return
                    // discards the memory, #1561, so this serves
                    // the away case). Its remembered Space is what
                    // places it if it comes back,
                    // and that memory answers once across every
                    // profile — so re-point it, or the profile's
                    // record loses to it (#1248).
                    if state.refileAway(of: window, to: space) {
                        refiled += 1
                    }
                    continue
                }
                let from = state.workspaces.space(of: window)
                guard from != space else { continue }
                state.workspaces.add(window, to: space)
                // A float crossing displays must re-anchor
                // (#444): membership alone never moves it, since
                // no layout frame is computed for a float. The
                // same pairing `pruneSpaces` makes twenty lines
                // away, and every other cross-space move site.
                reanchorFloat(window, to: space)
                // Its frame is the other Space's layout's (#1177).
                refiledWindows.insert(window)
                moved += 1
            }
        }
        state.workspaces.restoreFocusTrackers(
            lastFocused: heldFocus,
            candidate: heldCandidate,
            spaceFocus: heldSpaceFocus
        )
        if moved > 0 || refiled > 0 {
            onLog(
                "\(arrangement.logLabel): restored \(moved) "
                    + "window(s) to their own Spaces"
                    + (refiled > 0
                        ? ", re-filed \(refiled) absent" : "")
            )
        }
    }
}
