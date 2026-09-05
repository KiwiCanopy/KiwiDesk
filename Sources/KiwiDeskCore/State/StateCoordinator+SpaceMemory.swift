import Foundation

/// Space memory accessors and provenance tracking (`StateCoordinator`, #1010).
extension StateCoordinator {
    /// Tracks origin and provenance of remembered window space associations
    /// (`StateSnapshot.adopt`, #1010).
    enum SpaceMemory: Sendable, Equatable {
        /// Window departure observed by destroy fold.
        case departed(SpaceID)
        /// Filed from session snapshot before window discovery.
        case restored(SpaceID)

        var space: SpaceID {
            switch self {
            case .departed(let space), .restored(let space):
                return space
            }
        }
    }

    /// Records restored space association for untracked window
    /// (`rememberedSpaces`, #1010).
    mutating func remember(_ id: WindowID, in space: SpaceID) {
        rememberedSpaces[id] = .restored(space)
    }

    /// Records the rank of every member of `space` as `id` departs
    /// it (#1207): each one's index today, raised past every
    /// sibling that already departed this space ahead of it — a
    /// burst folds one window at a time, so the index alone would
    /// read 0 for each. The stayers are re-ranked too, so a member
    /// that never departs (a carried sticky) ranks by where it
    /// sits rather than by a rank from an earlier departure.
    mutating func rememberDepartedSlot(
        of id: WindowID,
        in space: SpaceID
    ) {
        guard let members = workspaces[space]?.windows,
            members.contains(id)
        else { return }
        let departed = departedSlots.filter { entry in
            windows[entry.key] == nil
                && rememberedSpaces[entry.key] == .departed(space)
        }.values.sorted()
        for (index, member) in members.enumerated() {
            var rank = index
            for sibling in departed where sibling <= rank {
                rank += 1
            }
            departedSlots[member] = rank
        }
    }

    /// Re-files a departure the destroy fold just recorded under
    /// the Space an explicit Desktop-move target named (#1150).
    /// The one writer of `rememberedSpaces` OUTSIDE a fold, and
    /// safe as one because it runs in the same synchronous arm
    /// as that fold, before any reader: `forgetGoneWindow` reads
    /// nothing of it, and the away ledger files the NATIVE Space.
    /// The `.departed` memory takes the name and the slot rank is
    /// dropped, a rank meaning something only in the Space it was
    /// taken in; rankless, the create fold's spawn placement is
    /// the authority for where the return lands, and the away
    /// merge (`withAwayMembers`) previews it LAST, which may
    /// differ. A no-op for anything but a `.departed` record — a
    /// minimize, a close, a `.restored` filing.
    mutating func redirectDeparture(
        of id: WindowID,
        to space: SpaceID
    ) {
        guard case .departed? = rememberedSpaces[id] else { return }
        rememberedSpaces[id] = .departed(space)
        departedSlots[id] = nil
    }

    /// Retires a window closed while away (#1146): the ledger
    /// entry and the two #1207 records it was read with.
    mutating func forgetAway(_ id: WindowID) {
        awayWindows[id] = nil
        rememberedSpaces[id] = nil
        departedSlots[id] = nil
    }

    /// Clears all remembered space associations (`CGWindowID`, #634).
    public mutating func forgetRememberedSpaces() {
        rememberedSpaces = [:]
        departedSlots = [:]
        awayWindows = [:]
    }

    /// Retrieves remembered space identifier for untracked window.
    func rememberedSpace(of id: WindowID) -> SpaceID? {
        rememberedSpaces[id]?.space
    }
}
