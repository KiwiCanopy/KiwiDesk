import CoreGraphics

/// The snapshot restore's direct frame writes wait for the hand to
/// rest (#2626), through the one `oweAmbientWrite` door. The source
/// of the payment is the replay's own record, kept with the debt: a
/// capture cannot be re-derived from the desk as it now is, so the
/// payment re-checks that desk before it writes the record's frame.
extension KiwiCore {
    /// The replay a held restore write is paid from: its snapshot,
    /// the connected screens it was owed under (#633) and, per owed
    /// window, the record it reads and the Space it was filed in.
    struct RestoreDebt {
        struct Owed {
            var record: WindowID
            var space: SpaceID
        }

        let snapshot: StateSnapshot
        let screens: [String]
        var owed: [WindowID: Owed] = [:]

        /// A native tab switch re-keys the window, never its record.
        mutating func rekey(old: WindowID, new: WindowID) {
            owed[new] = owed.removeValue(forKey: old)
        }
    }

    /// Writes a tracked window's replayed frame now, or owes it
    /// while the motion gate holds. A `seeded` float owes nothing
    /// of its own: its stash seed rides the held pass (#1864), and
    /// what forgets the seed must not be paid over.
    func writeRestoredFrame(
        _ record: StateSnapshot.WindowRecord,
        from snapshot: StateSnapshot,
        seeded: Bool
    ) {
        let id = record.windowID
        guard oweAmbientWrite(.restore, for: id) else {
            tiler.setFrame(id, record.frame)
            return
        }
        guard !seeded, let space = state.workspaces.space(of: id)
        else { return }
        if restoreDebt == nil {
            restoreDebt = RestoreDebt(
                snapshot: snapshot,
                screens: liveFingerprints
            )
        }
        restoreDebt?.owed[id] = .init(record: id, space: space)
    }

    /// Pays an owed restore write from the replay's record and
    /// returns whether it wrote. Nothing is due once the screens
    /// changed (#633), the window left the Space the replay filed
    /// it in, or it sits at a corner, or its record is one (#1352).
    func payRestoreWrite(_ id: WindowID) -> Bool {
        guard let debt = restoreDebt, let owed = debt.owed[id],
            SleepWakeManager.sameTopology(liveFingerprints, debt.screens),
            state.workspaces.space(of: id) == owed.space,
            let record = debt.snapshot.windows.first(where: {
                $0.windowID == owed.record
            }),
            let current = state.windows[id]?.frame,
            !tiler.looksStashed(record.frame),
            !tiler.looksStashed(current)
        else { return false }
        tiler.setFrame(id, record.frame)
        return true
    }

    /// Forgets the held restore writes: they were paid, or a newer
    /// replay, a rest, a stop or a discarded arrangement supersedes
    /// the replay that owed them.
    func dropRestoreDebt() {
        tiler.motionGate.forgetWrites(.restore)
        restoreDebt = nil
    }
}
