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
    /// Files the live Spaces under the profile that is live NOW —
    /// `profiles.currentName`, the one authority for whose
    /// arrangement is on screen (#1249).
    ///
    /// Call it while that is still true. Every verb that moves
    /// the name — an apply, a save — files first and moves
    /// second, and a nil name files nothing because a built-in
    /// Standard (or a session that has applied nothing) has no
    /// partitioning of its own.
    func recordLivePartitioning() {
        state.profilePartitioning.record(
            state.workspaces.allSpaces,
            as: profiles.currentName
        )
    }

    /// Files the outgoing profile's partitioning before the space
    /// set is rebuilt. Returns whether this apply is a CHANGE, so
    /// the caller gates the prune and the restore on one answer.
    ///
    /// A re-apply of the LIVE profile, or the session's first,
    /// files nothing and restores nothing — neither a monitor
    /// reconnect nor boot may revert what is already on screen.
    func recordOutgoingPartitioning(
        before profile: Profile
    ) -> Bool {
        guard
            state.profilePartitioning.isSwitch(
                to: profile.name,
                from: profiles.currentName
            )
        else { return false }
        recordLivePartitioning()
        return true
    }

    /// The one profile WRITE door (#1249). `ProfileManager.save`
    /// makes its argument current, so the outgoing name — the one
    /// the arrangement on screen belongs to — is gone the moment
    /// it returns; filing has to happen first.
    ///
    /// Unconditional rather than a caller's choice. On the preset
    /// path `apply(composed:)` has already filed the outgoing
    /// profile and `adoptStandard` has stood the name down, so
    /// the record here is a no-op — which is why no exit has to
    /// decide, and why the third one could ship un-filed (#1246).
    func saveProfile(_ profile: Profile) throws {
        recordLivePartitioning()
        try profiles.save(profile)
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
    /// Only LIVE windows move: a remembered id can belong to a
    /// window since closed, or to one sitting on an away Desktop
    /// (#1146), and inserting either would put a phantom in the
    /// row. The away case comes back through its own memory
    /// (`rememberedSpaces`), not this one.
    ///
    /// A remembered Space the profile no longer declares is
    /// skipped rather than re-created: the prune just dropped it,
    /// and `WorkspaceManager.add` would silently `ensureSpace` it
    /// back into a set the profile is authoritative over.
    func restorePartitioning(of profile: Profile) {
        guard
            let remembered = state.profilePartitioning.remembered(
                for: profile.name
            )
        else { return }
        let declared = profile.declaredSpaces
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
        for space in SpaceID.numericLexicalSorted(
            Array(remembered.keys)
        ) {
            guard declared.contains(space),
                state.workspaces[space] != nil
            else { continue }
            for window in remembered[space] ?? []
            where state.windows[window] != nil {
                let from = state.workspaces.space(of: window)
                state.workspaces.add(window, to: space)
                // A float crossing displays must re-anchor
                // (#444): membership alone never moves it, since
                // no layout frame is computed for a float. The
                // same pairing `pruneSpaces` makes twenty lines
                // away, and every other cross-space move site.
                if from != space {
                    reanchorFloat(window, to: space)
                }
                moved += 1
            }
        }
        state.workspaces.restoreFocusTrackers(
            lastFocused: heldFocus,
            candidate: heldCandidate,
            spaceFocus: heldSpaceFocus
        )
        if moved > 0 {
            onLog(
                "profile '\(profile.name)': restored \(moved) "
                    + "window(s) to their own Spaces"
            )
        }
    }
}
