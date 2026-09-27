import Foundation

/// Held Spaces across a restart (#1646): boot re-creates the held
/// Spaces the session snapshot recorded before the replay files
/// their windows, and sends home at once those whose screen is
/// back. Writes no `heldSpaces` — `restoreHolds` and the re-file
/// are `KiwiCore+HeldSpaces.swift`'s.
extension KiwiCore {
    /// What the boot tail owes after the replay.
    struct BootHolds {
        /// The snapshot the replay adopts, held ids renamed.
        var snapshot: StateSnapshot
        /// The live mode of each declared Space a held record
        /// went home into, which the replay's record would
        /// otherwise overwrite with the held Space's.
        var homeModes: [SpaceID: LayoutMode] = [:]
        var renumbered = false
    }

    /// The Spaces the live arrangement declares, from adoption
    /// state (#1245).
    var liveDeclaredSpaces: Set<SpaceID> {
        profiles.active?.declaredSpaces ?? profiles.standard?.spaces ?? []
    }

    /// Re-creates the snapshot's held Spaces, ahead of `restore`.
    /// A record none of whose windows the scan found is dropped —
    /// it would hold nothing, and #1507 begins no hold for a
    /// remembered-only Space. One about to go home under its own
    /// name is filed straight into the declared Space. A held id a
    /// live Space already takes is renumbered past every live
    /// number, keeping the batch's order (#1664), as
    /// `reclaimHeldNames` does.
    func restoreHeldSpaces(from snapshot: StateSnapshot) -> BootHolds {
        var plan = BootHolds(snapshot: snapshot)
        guard !snapshot.held.isEmpty else { return plan }
        let arrangement = liveArrangement
        let declared = liveDeclaredSpaces
        var members: [String: [UInt32]] = [:]
        for record in snapshot.spaces { members[record.id] = record.windows }
        var kept: [StateSnapshot.HeldRecord] = []
        var dropped: Set<String> = []
        for record in snapshot.held {
            let id = record.spaceID
            let survived = (members[record.id] ?? []).contains {
                state.windows[WindowID($0)] != nil
            }
            guard survived else {
                dropped.insert(record.id)
                onLog(
                    "restart: held space \(id.raw) dropped — none of "
                        + "its windows came back"
                )
                continue
            }
            if id == record.origin.name, let arrangement,
                returnsHome(
                    record.origin,
                    declared: declared,
                    into: arrangement
                ),
                let live = state.workspaces[id]
            {
                plan.homeModes[id] = live.mode
                onLog(
                    "restart: held space \(id.raw) is home on "
                        + "'\(record.origin.screenName)'"
                )
                continue
            }
            kept.append(record)
        }
        plan.snapshot.spaces.removeAll { dropped.contains($0.id) }
        let taken = declared.union(state.workspaces.allSpaces.map(\.id))
            .union(snapshot.held.map(\.spaceID))
            .union(state.rememberedSpaces.values.map(\.space))
        let ids = kept.map(\.spaceID)
        let names = Self.orderedHeldNames(
            ids,
            taken: taken,
            mustMove: { state.workspaces[$0] != nil }
        )
        var renames: [SpaceID: SpaceID] = [:]
        for (id, name) in zip(ids, names) where id != name {
            renames[id] = name
        }
        plan.renumbered = !renames.isEmpty
        plan.snapshot = plan.snapshot.renamingSpaces(renames)
        restoreHolds(
            zip(names, kept).map { (id: $0, origin: $1.origin) }
        )
        return plan
    }

    /// After the replay: the home Spaces' own modes back, every
    /// held Space whose screen is connected re-filed as a
    /// reconnect would, and a renumbered one's digit chord owed.
    func settleHeldSpacesAtBoot(_ plan: BootHolds) {
        for (id, mode) in plan.homeModes { setSpaceMode(id, mode) }
        guard !state.heldSpaces.isEmpty || !plan.homeModes.isEmpty
        else { return }
        if let arrangement = liveArrangement {
            refileHeldSpaces(
                declared: liveDeclaredSpaces,
                into: arrangement
            )
        }
        if plan.renumbered { topUpDigitShortcuts() }
        resolveSpaceDisplays()
    }
}
