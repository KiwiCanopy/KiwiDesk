import Foundation

/// The PROFILE axis of #1230 — the one door onto "whose Spaces
/// are live, and what did the last profile leave behind".
/// `ProfileSpacesSeamTests` pins that `profilePartitioning` is
/// reached only from here and its four enders.
///
/// The Desktop axis is `KiwiCore+DesktopSpaces.swift`, and the
/// two are deliberately separate: a window's Desktop is the
/// WindowServer's fact and is never stored, while its Space under
/// a given profile is KiwiDesk's own and must be. Different
/// subjects that merely rhyme — folding them would give the
/// stored half the unstored half's lifetime.
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
            // Seeds the live slot on the session's first apply;
            // a re-apply of the live profile re-seeds to itself,
            // which is what makes it a no-op.
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
        var moved = 0
        for space in SpaceID.numericLexicalSorted(
            Array(remembered.keys)
        ) {
            guard declared.contains(space),
                state.workspaces[space] != nil
            else { continue }
            for window in remembered[space] ?? []
            where state.windows[window] != nil {
                state.workspaces.add(window, to: space)
                moved += 1
            }
        }
        if moved > 0 {
            onLog(
                "profile '\(profile.name)': restored \(moved) "
                    + "window(s) to their own Spaces"
            )
        }
    }
}
