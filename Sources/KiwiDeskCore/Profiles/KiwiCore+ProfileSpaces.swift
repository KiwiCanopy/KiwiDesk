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
    /// Files the outgoing profile's partitioning before the space
    /// set is rebuilt. Returns whether this apply is a CHANGE, so
    /// the caller gates the prune and the restore on one answer.
    func recordOutgoingPartitioning(
        before profile: Profile
    ) -> Bool {
        let switching = state.profilePartitioning.isSwitch(
            to: profile.name
        )
        guard switching else {
            // A re-apply of the LIVE profile, or the session's
            // first: file nothing and restore nothing, so neither
            // a monitor reconnect nor boot can revert what is
            // already on screen. Seeding the slot here is what
            // makes the NEXT apply a switch.
            state.profilePartitioning.adoptLive(profile.name)
            return false
        }
        state.profilePartitioning.record(
            state.workspaces.allSpaces,
            handingLiveTo: profile.name
        )
        return true
    }

    /// A built-in Standard is not a profile and has no
    /// partitioning of its own, so entering one files the
    /// OUTGOING profile's and leaves the live slot empty.
    ///
    /// Without this, profile A → Standard → profile B records the
    /// STANDARD's arrangement under A's name: the live slot would
    /// still read "A" when B arrives, and what it files is
    /// whatever is on screen by then.
    func recordOutgoingPartitioningForStandard() {
        guard state.profilePartitioning.liveProfile != nil
        else { return }
        state.profilePartitioning.record(
            state.workspaces.allSpaces,
            handingLiveTo: nil
        )
    }

    /// A SAVE adopts too, so the live slot follows it (#1230).
    ///
    /// `ProfileManager.save` sets `currentName`, which is what
    /// makes the saved profile the current one — but the
    /// partitioning tracks the live slot separately, because
    /// `currentName` cannot answer "which profile do the live
    /// Spaces represent" at apply time. Left un-adopted, saving
    /// your arrangement as a profile and then switching away
    /// files NOTHING for it: the switch is not a switch, because
    /// the slot never named it. Measured on the device
    /// 2026-09-04 — arrange, `save_profile A`, `save_profile B`,
    /// `load_profile B`, rearrange, `load_profile A` returned
    /// B's arrangement (#1246).
    ///
    /// Files whatever WAS live first: at the moment of a
    /// capture-live save the two arrangements are identical, so
    /// the outgoing profile's record is written from the same
    /// Spaces rather than lost.
    func adoptSavedProfile(_ name: String) {
        state.profilePartitioning.record(
            state.workspaces.allSpaces,
            handingLiveTo: name
        )
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
