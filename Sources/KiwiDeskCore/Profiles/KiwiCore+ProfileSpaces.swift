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
    /// Files the live Spaces under `profiles.currentName`, so
    /// every verb that moves that name files first and moves
    /// second — profiles.md ▸ "Whose arrangement is live" (#1249).
    ///
    /// A nil name files nothing: a built-in Standard, or a session
    /// that has applied nothing, has no partitioning of its own.
    func recordLivePartitioning() {
        state.profilePartitioning.record(
            state.workspaces.allSpaces.map {
                Space(
                    id: $0.id,
                    windows: withAwayMembers($0.windows, of: $0.id)
                )
            },
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
    /// makes its argument current, so the outgoing name is gone
    /// the moment it returns; the filing has to precede it.
    ///
    /// Unconditional rather than a caller's choice: on the preset
    /// path `apply(composed:)` has already filed and stood the
    /// name down through `noProfileIsLive`, so the record here is
    /// a no-op — which is what leaves no exit anything to decide.
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
        var refiled = 0
        for space in SpaceID.numericLexicalSorted(
            Array(remembered.keys)
        ) {
            guard declared.contains(space),
                state.workspaces[space] != nil
            else { continue }
            for window in remembered[space] ?? [] {
                guard state.windows[window] != nil else {
                    // Not in state: away on another Desktop, or
                    // closed and still remembered. Its remembered
                    // Space is what places it if it comes back,
                    // and that memory answers once across every
                    // profile — so re-point it, or the profile's
                    // record loses to it (#1248).
                    if state.refileAway(of: window, to: space) {
                        refiled += 1
                    }
                    continue
                }
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
        if moved > 0 || refiled > 0 {
            onLog(
                "profile '\(profile.name)': restored \(moved) "
                    + "window(s) to their own Spaces"
                    + (refiled > 0
                        ? ", re-filed \(refiled) absent" : "")
            )
        }
    }
}
