import Foundation

/// Held Spaces across a restart (#1646): boot holds the Spaces the
/// session snapshot recorded as held before the replay files
/// their windows, sends home at once those whose screen is back,
/// and lets #1507's retire end one only once the WindowServer says
/// its windows are gone. Writes no `heldSpaces` — `restoreHolds`
/// and the re-file are `KiwiCore+HeldSpaces.swift`'s.
extension KiwiCore {
    /// What the boot tail owes after the replay.
    struct BootHolds {
        /// The snapshot the replay adopts, held ids renamed.
        var snapshot: StateSnapshot
        /// Each held Space's live id and the windows it holds
        /// that are not members.
        var remembered: [SpaceID: [WindowID]] = [:]
        /// The live mode of each declared Space a hold goes home
        /// into in place, which the replay's record would
        /// otherwise overwrite with the held Space's.
        var homeModes: [SpaceID: LayoutMode] = [:]
        var renumbered = false
    }

    /// Holds every Space the snapshot recorded as held, ahead of
    /// `restore`. One going home under its own name keeps it; any
    /// other whose id a live, declared or recorded Space already
    /// takes is renumbered past all of them in the batch's order
    /// (#1664) — the reclaim's rule, applied to the record — so
    /// the replay never merges two records into one Space.
    func restoreHeldSpaces(from snapshot: StateSnapshot) -> BootHolds {
        var plan = BootHolds(snapshot: snapshot)
        let records = snapshot.spaces.compactMap { record in
            record.held.map { (id: SpaceID(record.id), held: $0) }
        }
        guard !records.isEmpty else { return plan }
        let home = liveHome
        let declared = home?.declared ?? []
        let inPlace = records.filter { record in
            home.map {
                goesHomeInPlace(
                    record.id,
                    record.held.origin,
                    declared: $0.declared,
                    into: $0.arrangement
                )
            } ?? false
        }
        let walked = records.filter { record in
            !inPlace.contains { $0.id == record.id }
        }
        for record in inPlace {
            plan.homeModes[record.id] = state.workspaces[record.id]?.mode
        }
        var taken = declared.union(state.workspaces.allSpaces.map(\.id))
            .union(snapshot.spaces.map { SpaceID($0.id) })
            .union(state.rememberedSpaces.values.map(\.space))
        if let active = snapshot.activeSpace { taken.insert(SpaceID(active)) }
        let names = Self.orderedHeldNames(
            walked.map(\.id),
            taken: taken,
            mustMove: { declared.contains($0) || state.workspaces[$0] != nil }
        )
        var renames: [SpaceID: SpaceID] = [:]
        for (record, name) in zip(walked, names) where record.id != name {
            renames[record.id] = name
        }
        plan.renumbered = !renames.isEmpty
        plan.snapshot = snapshot.renamingSpaces(renames)
        let holds =
            inPlace.map { (id: $0.id, held: $0.held) }
            + zip(walked, names).map { (id: $1, held: $0.held) }
        for hold in holds {
            plan.remembered[hold.id] = hold.held.remembered.map(WindowID.init)
        }
        restoreHolds(holds.map { (id: $0.id, origin: $0.held.origin) })
        return plan
    }

    /// After the replay: each hold's non-member windows remembered
    /// there, every held Space whose screen is connected re-filed
    /// as a reconnect would, one back in place given its own mode
    /// again, and a renumbered one's digit chord owed.
    func settleHeldSpacesAtBoot(_ plan: BootHolds) {
        guard !plan.remembered.isEmpty else { return }
        for (space, windows) in plan.remembered {
            for id in windows
            where state.windows[id] == nil
                && state.rememberedSpaces[id] == nil
            {
                state.remember(id, in: space)
            }
        }
        // With no arrangement live (a hand-written config) nothing
        // goes home and nothing is pinned, as at a reconnect.
        if let home = liveHome {
            for id in refileHeldSpaces(
                declared: home.declared,
                into: home.arrangement
            ) {
                setSpaceMode(id, plan.homeModes[id] ?? .bsp)
            }
        }
        if plan.renumbered { topUpDigitShortcuts() }
        resolveSpaceDisplays()
    }

    /// Boot's last word on the restored holds, after the away seed:
    /// a window a held Space remembers that the WindowServer hosts
    /// on no Space at all is gone for good — a relaunched app's,
    /// one closed while KiwiDesk was down — so its filing is
    /// dropped and #1507's retire ends a hold left with nothing.
    /// The per-window read, not the Desktop census, which lists
    /// user Desktops only. Measured 2026-09-28 on macOS 27.0 with
    /// this selector (0x7): a window of a hidden app and a
    /// minimized one read hosted, a closed one reads no Space.
    /// Away, fullscreen and still-launching windows are reasoned
    /// to read hosted, not measured. An unanswered read judges
    /// nothing (absent, never faked) and marks the filing, which
    /// the snapshot then does not carry again.
    func retireGoneHeldMembers() {
        let filed = state.rememberedSpaces.compactMap { entry in
            guard case .restored(let space) = entry.value,
                state.heldSpaces[space] != nil,
                state.windows[entry.key] == nil
            else { return nil as WindowID? }
            return entry.key
        }
        guard !filed.isEmpty else { return }
        var gone: [WindowID] = []
        for id in filed.sorted(by: { $0.raw < $1.raw }) {
            switch desktopMemory.readWindowSpace(id) {
            case .gone: gone.append(id)
            case .hosted: break
            case .unavailable: state.unjudgedFilings.insert(id)
            }
        }
        if !state.unjudgedFilings.isEmpty {
            onLog("restart: held windows could not be judged")
        }
        guard !gone.isEmpty else { return }
        for id in gone { state.forgetRestoredFiling(of: id) }
        onLog("restart: \(gone.count) held window(s) did not come back")
        retile()
    }
}
