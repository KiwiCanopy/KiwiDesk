import Foundation

/// Boot's way back to the temporary Spaces (#1790): the other
/// Space a restore creates, beside the held one (#1646), and on
/// the same ground — no arrangement write captures either.
extension KiwiCore {
    /// Re-creates each Space the snapshot recorded as temporary,
    /// ahead of the replay that files its windows — only when
    /// KiwiDesk boots into the arrangement the snapshot was taken
    /// under, since booting into another is a switch made while it
    /// was down. A number the booting arrangement declares, or a
    /// Space that already exists, is that arrangement's, so the
    /// replay files into it as it is.
    func restoreTemporarySpaces(from snapshot: StateSnapshot) {
        guard snapshot.arrangement == liveArrangement else { return }
        let declared = liveHome?.declared ?? []
        for record in snapshot.spaces {
            guard let temporary = record.temporary, record.held == nil
            else { continue }
            let id = SpaceID(record.id)
            guard !declared.contains(id), state.workspaces[id] == nil
            else { continue }
            state.workspaces.ensureSpace(id, mode: record.mode)
            state.temporarySpaces[id] = TemporarySpace(
                armed: temporary.armed
            )
            if let pin = temporary.pin { spacePins[id] = pin }
            onLog("restart: temporary space \(id.raw)")
        }
    }
}
