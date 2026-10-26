import CoreGraphics

/// The snapshot restore's direct frame writes wait for the hand to
/// rest (#2626), through the one `oweAmbientWrite` door: the window
/// is owed, and its payment re-reads the frame from the replay's
/// snapshot, never a frame stored beside the debt.
extension KiwiCore {
    /// The replay a held restore write is paid from: its snapshot,
    /// the connected screens it was owed under (#633) and the Space
    /// it filed each owed window in.
    struct RestoreDebt {
        let snapshot: StateSnapshot
        let screens: [String]
        var spaces: [WindowID: SpaceID] = [:]
    }

    /// Writes a tracked window's replayed frame now, or owes it
    /// while the motion gate holds.
    func writeRestoredFrame(
        _ record: StateSnapshot.WindowRecord,
        from snapshot: StateSnapshot
    ) {
        let id = record.windowID
        guard oweAmbientWrite(.restore, for: id) else {
            tiler.setFrame(id, record.frame)
            return
        }
        if restoreDebt == nil {
            restoreDebt = RestoreDebt(
                snapshot: snapshot,
                screens: liveFingerprints.sorted()
            )
        }
        restoreDebt?.spaces[id] = state.workspaces.space(of: id)
    }

    /// Pays an owed restore write from the replay's snapshot and
    /// returns whether it wrote. Nothing is due once the screens
    /// changed (#633), the window left the Space the replay filed
    /// it in, or a corner, a park or a stash capture answers for it
    /// (#1352): a float's seed is delivered by this pass (#1864).
    func payRestoreWrite(_ id: WindowID) -> Bool {
        guard let debt = restoreDebt, tiler.stashedFrames[id] == nil,
            liveFingerprints.sorted() == debt.screens,
            let space = debt.spaces[id],
            state.workspaces.space(of: id) == space,
            let record = debt.snapshot.windows.first(where: {
                $0.windowID == id
            }),
            let current = state.windows[id]?.frame,
            !tiler.looksStashed(record.frame),
            !tiler.looksStashed(current)
        else { return false }
        tiler.setFrame(id, record.frame)
        return true
    }

    /// Forgets the held restore writes: a newer replay, a rest or a
    /// stop supersedes the replay that owed them.
    func dropRestoreDebt() {
        tiler.motionGate.forgetWrites(.restore)
        restoreDebt = nil
    }
}
