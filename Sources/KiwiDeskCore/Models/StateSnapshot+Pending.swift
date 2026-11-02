import Foundation

/// The windows a Space has filed that have not arrived (#2008):
/// every capture carries them, so a stop before they arrive does
/// not drop their Space.
extension StateCoordinator {
    /// One Space's record as every capture builds it: a held Space
    /// carries its pending filings on the hold, any other on
    /// `pending` (#1646, #2008).
    func spaceRecord(
        of space: Space,
        session: StateSnapshot.SpaceSession? = nil
    ) -> StateSnapshot.SpaceRecord {
        StateSnapshot.SpaceRecord(
            space: space,
            session: session,
            held: heldRecord(of: space.id),
            pending: heldSpaces[space.id] == nil
                ? pendingFilings(in: space.id) : []
        )
    }

    /// The windows filed in Space `id` that have not arrived, in
    /// the order their slots give, unranked ones last by id: the
    /// list's order carries the slots across a restart (#2907). A
    /// filing's kind ends there, each coming back `.restored`.
    func pendingFilings(in id: SpaceID) -> [WindowID] {
        rememberedSpaces.filter {
            guard $0.value.space == id,
                windows[$0.key] == nil,
                !closedDepartures.contains($0.key)
            else { return false }
            // An unjudged restored filing is not carried again.
            if case .restored = $0.value {
                return !unjudgedFilings.contains($0.key)
            }
            return true
        }.keys.sorted(by: slotOrder)
    }

    /// The row order `departedSlots` gives, unranked windows last by
    /// id: the capture's and the away preview's one rule (#2907).
    func slotOrder(_ a: WindowID, _ b: WindowID) -> Bool {
        (departedSlots[a]?.rank ?? .max, a.raw)
            < (departedSlots[b]?.rank ?? .max, b.raw)
    }

    /// What those windows are owed at arrival (#1362, #1864), as
    /// window records, so a second capture keeps it too.
    func owedFrameRecords() -> [StateSnapshot.WindowRecord] {
        restoredFrames.compactMap { id, owed in
            windows[id] == nil && rememberedSpaces[id] != nil
                && !unjudgedFilings.contains(id)
                ? StateSnapshot.WindowRecord(
                    id: id,
                    frame: owed.frame,
                    floating: owed.floating ? true : nil
                ) : nil
        }.sorted { $0.id < $1.id }
    }

    /// Files each window back that is neither live nor filed, its
    /// place in `ids` as its slot (#2907): a window the boot census
    /// finds on another Desktop resumes its departure through
    /// `resumeCarriedDeparture` and returns to that slot.
    mutating func refilePending(_ ids: [WindowID], in space: SpaceID) {
        for (rank, id) in ids.enumerated()
        where windows[id] == nil && rememberedSpaces[id] == nil {
            remember(id, in: space)
            if departedSlots[id] == nil {
                departedSlots[id] = DepartedSlot(rank: rank)
            }
        }
    }

    /// Turns a carried filing back into the Desktop departure it
    /// was (#2907), so its return takes its slot as a live
    /// session's would; false for anything but a carried filing.
    @discardableResult
    mutating func resumeCarriedDeparture(_ id: WindowID) -> Bool {
        guard case .restored(let space)? = rememberedSpaces[id],
            departedSlots[id] != nil
        else { return false }
        rememberedSpaces[id] = .departed(space)
        return true
    }
}

extension StateSnapshot {
    /// This snapshot without its pending filings: a wake replay's,
    /// whose process still holds its own (#2008).
    func droppingPending() -> StateSnapshot {
        var copy = self
        for index in copy.spaces.indices {
            copy.spaces[index].pending = []
        }
        return copy
    }
}
