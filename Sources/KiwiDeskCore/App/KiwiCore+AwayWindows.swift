import Foundation

/// The away ledger's writers and readers (#1146):
/// `StateCoordinator.awayWindows`, beside the visible-only state.
/// An entry is written on a compositor-confirmed `vanished` and
/// at the boot census, pruned by a census that no longer hosts
/// the id (the corrective `closed`), and read by the Space Bar,
/// Open-or-Focus and `get_state`. The argument is
/// state-and-layout.md's.
extension KiwiCore {
    /// The cadence the ledger is re-read at while non-empty.
    static let awayCensusInterval: Duration = .seconds(5)

    /// Files `id` as away, from the facts the fold erased.
    func recordAwayWindow(
        _ id: WindowID,
        removed: AppliedEffects.RemovedWindow?,
        nativeSpace: SkyLight.SpaceID
    ) {
        guard let removed, let pid = removed.pid,
            !removed.isTransientOverlay
        else { return }
        state.awayWindows[id] = AwayWindow(
            id: id,
            pid: pid,
            appName: removed.app ?? "",
            appBundleID: removed.bundleID,
            nativeSpace: nativeSpace
        )
        scheduleAwayCensus()
    }

    /// Re-reads the ledger against ONE census: an entry the
    /// WindowServer no longer hosts is a window closed while
    /// away — pruned, and reported `closed` the way its close
    /// would have been had the Desktop been shown. A no-op
    /// without a census (absent, never faked).
    func refreshAwayWindows() {
        guard !state.awayWindows.isEmpty else { return }
        let spaces = NativeSpaces.allSpaces()
        guard let census = desktopMemory.readCensus(spaces) else { return }
        for entry in state.awayWindows.values.sorted(by: {
            $0.id.raw < $1.id.raw
        }) {
            guard let host = census.hosts[entry.id] else {
                pruneAwayWindow(entry)
                continue
            }
            state.awayWindows[entry.id]?.nativeSpace = host.space
        }
    }

    private func pruneAwayWindow(_ entry: AwayWindow) {
        let space = state.rememberedSpace(of: entry.id)
        state.awayWindows[entry.id] = nil
        state.rememberedSpaces[entry.id] = nil
        state.departedSlots[entry.id] = nil
        onLog(
            "away: w\(entry.id.raw) (\(entry.appName)) closed "
                + "while its Desktop was away"
        )
        emitWindowDestroyed(
            entry.id,
            app: entry.appName,
            bundleID: entry.appBundleID,
            space: space,
            reason: .closed
        )
    }

    /// Arms the periodic re-read; self-re-arming while the
    /// ledger is non-empty, so an empty ledger costs nothing.
    func scheduleAwayCensus() {
        guard !state.awayWindows.isEmpty else { return }
        deferred.schedule(
            .awayCensus,
            after: Self.awayCensusInterval
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning else { return }
            self.refreshAwayWindows()
            self.scheduleAwayCensus()
        }
    }

    /// The boot census (#1146): every layer-0 window of an
    /// observed app that sits on a Desktop nobody shows joins
    /// the ledger, filed under the session snapshot's space
    /// where the id is in it (`.restored`, #1010), else the
    /// Desktop's remembered Space, else UNFILED — known to the
    /// classifier and Open-or-Focus, drawn on no bar until its
    /// reveal files it.
    func seedAwayWindows() {
        let spaces = NativeSpaces.allSpaces()
        guard let census = desktopMemory.readCensus(spaces) else { return }
        let refs = Dictionary(
            eventLoop.runningApplications().map { ($0.pid, $0.ref) },
            uniquingKeysWith: { first, _ in first }
        )
        let key = Self.virtualSpaceMemoryKey(
            mainUUID: NativeSpaces.mainDisplayUUID()
        )
        var seeded = 0
        for (id, host) in census.hosts.sorted(by: {
            $0.key.raw < $1.key.raw
        }) {
            guard census.isAway(id),
                state.windows[id] == nil,
                state.awayWindows[id] == nil,
                eventLoop.observes(pid: host.pid),
                let ref = refs[host.pid]
            else { continue }
            state.awayWindows[id] = AwayWindow(
                id: id,
                pid: host.pid,
                appName: ref.name,
                appBundleID: ref.bundleID,
                nativeSpace: host.space
            )
            if state.rememberedSpace(of: id) == nil,
                let number = NativeSpaces.number(of: host.space, in: spaces),
                let space = desktopMemory.virtualSpaces[key]?[number],
                state.workspaces[space] != nil
            {
                state.remember(id, in: space)
            }
            seeded += 1
        }
        if seeded > 0 {
            onLog("boot census: \(seeded) window(s) on away Desktops")
            scheduleAwayCensus()
        }
    }

    /// The away members of `space`, in the order the row would
    /// come back (#1207's rank), unfiled entries excluded.
    func awayMembers(of space: SpaceID) -> [WindowID] {
        state.awayWindows.keys
            .filter { state.rememberedSpace(of: $0) == space }
            .sorted {
                (state.departedSlots[$0] ?? .max, $0.raw)
                    < (state.departedSlots[$1] ?? .max, $1.raw)
            }
    }

    /// An app's away windows, spaces in canonical order and by
    /// rank inside each, unfiled entries last. `bundleID`
    /// arrives lowercased (the command's normalization).
    func awayWindows(bundleID: String) -> [AwayWindow] {
        let entries = state.awayWindows.values.filter {
            $0.appBundleID?.lowercased() == bundleID
        }
        guard !entries.isEmpty else { return [] }
        var ordered: [AwayWindow] = []
        for space in state.workspaces.allSpaces {
            for id in awayMembers(of: space.id) {
                if let entry = state.awayWindows[id],
                    entries.contains(entry)
                {
                    ordered.append(entry)
                }
            }
        }
        let filed = Set(ordered.map(\.id))
        ordered +=
            entries
            .filter { !filed.contains($0.id) }
            .sorted { $0.id.raw < $1.id.raw }
        return ordered
    }
}

extension KiwiCore {
    /// `base` with the space's away members inserted by the rank
    /// they will return in — the fold's own insert
    /// (`Space.insert(_:rank:ranks:)`), so a bar item and the
    /// Open-or-Focus ring read the row as the return rebuilds it.
    func withAwayMembers(
        _ base: [WindowID],
        of space: SpaceID
    ) -> [WindowID] {
        let away = awayMembers(of: space)
        guard !away.isEmpty else { return base }
        var members = base
        for id in away where !members.contains(id) {
            guard let rank = state.departedSlots[id] else {
                members.append(id)
                continue
            }
            let index =
                members.firstIndex { member in
                    state.departedSlots[member].map { $0 > rank }
                        ?? false
                } ?? members.count
            members.insert(id, at: index)
        }
        return members
    }
}
