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

    /// The windows filed in Space `id` that have not arrived. A
    /// filing's kind and a departure's slot end at a restart: each
    /// comes back a `.restored` filing at the end of its row.
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
        }.keys.sorted { $0.raw < $1.raw }
    }

    /// The frames owed at those windows' arrival (#1362), as window
    /// records, so a second stop keeps them too.
    func owedFrameRecords() -> [StateSnapshot.WindowRecord] {
        restoredFrames.compactMap { id, frame in
            windows[id] == nil && rememberedSpaces[id] != nil
                && !unjudgedFilings.contains(id)
                ? StateSnapshot.WindowRecord(id: id, frame: frame) : nil
        }.sorted { $0.id < $1.id }
    }

    /// Files each window back that is neither live nor filed.
    mutating func refilePending(_ ids: [WindowID], in space: SpaceID) {
        for id in ids
        where windows[id] == nil && rememberedSpaces[id] == nil {
            remember(id, in: space)
        }
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
