import Foundation

/// The away ledger's writers and readers (#1146):
/// `StateCoordinator.awayWindows`, beside the visible-only state.
/// An entry is written on a compositor-confirmed `vanished` and
/// at the boot census, pruned by a census that no longer hosts
/// the id (the corrective `closed`), and read by Open-or-Focus
/// and `get_state` — never the Space Bar, which draws the
/// Desktop in front of the user (#1228). The argument is
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
    /// without a census (absent, never faked); returns whether
    /// one was read, which is what keeps the task armed.
    @discardableResult
    func refreshAwayWindows() -> Bool {
        guard !state.awayWindows.isEmpty else { return false }
        let spaces = NativeSpaces.allSpaces()
        guard let census = desktopMemory.readCensus(spaces) else {
            return false
        }
        fold(census, pruning: true)
        return true
    }

    /// Folds ONE census into the ledger — the reading every
    /// consumer of the ledger then sees, so a keystroke and
    /// `get_state` never disagree about a window's Desktop or
    /// parking.
    /// `pruning: false` updates hosts and parking only: a prune
    /// emits a `window_destroyed` synchronously, which a command
    /// in flight must not do mid-dispatch (a Lua handler may
    /// `execute` back in) — the settle and the task prune.
    /// Nothing here redraws: no bar reads the ledger (#1228),
    /// and a prune's own `window_destroyed` is what a consumer
    /// hears.
    func fold(_ census: DesktopCensus, pruning: Bool) {
        for entry in state.awayWindows.values.sorted(by: {
            $0.id.raw < $1.id.raw
        }) {
            guard let host = census.hosts[entry.id] else {
                if pruning { pruneAwayWindow(entry) }
                continue
            }
            state.awayWindows[entry.id]?.nativeSpace = host.space
            state.awayWindows[entry.id]?.isUp = host.isUp
        }
    }

    /// Retires what still names a window that is gone for good:
    /// the #1207 focus memory and both arrival debts — a debt to
    /// a window that can never arrive would hold the settle's
    /// refocus down for nothing.
    func retireAwayDebts(of id: WindowID) {
        retireDesktopFocus(of: id)
        desktopMemory.returnFocus.retire(id)
        followFocus.retire(id)
    }

    /// The app's exit ends its entries (the state fold) and
    /// what named them (#1146).
    func retireAwayDebts(ofExitedApp pid: pid_t) {
        for entry in state.awayWindows.values where entry.pid == pid {
            retireAwayDebts(of: entry.id)
        }
    }

    private func pruneAwayWindow(_ entry: AwayWindow) {
        let space = state.rememberedSpace(of: entry.id)
        state.forgetAway(entry.id)
        retireAwayDebts(of: entry.id)
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
    /// ledger is non-empty AND the last read answered, so an
    /// empty ledger costs nothing and a failed read does not
    /// poll — the next vanish, boot seed or Desktop settle
    /// re-arms it.
    func scheduleAwayCensus() {
        guard !state.awayWindows.isEmpty else { return }
        deferred.schedule(
            .awayCensus,
            after: Self.awayCensusInterval
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning else { return }
            if self.refreshAwayWindows() {
                self.scheduleAwayCensus()
            }
        }
    }

    /// The boot census (#1146): every layer-0 window of an
    /// observed app that sits UP on a Desktop nobody shows joins
    /// the ledger, filed under the session snapshot's space
    /// where the id is in it (`.restored`, #1010), else the
    /// Desktop's remembered Space, else UNFILED — known to the
    /// classifier and Open-or-Focus, filed at its reveal.
    ///
    /// **A PARKED window is not seeded (#1234)**, which applies
    /// at boot the rule the runtime already applies: every
    /// consumer requires `isUp` — `awayMembers(of:)` filters on
    /// it and the reach re-reads it from its own census — so a
    /// parked entry can serve nobody, and "minimized while away
    /// is not reachable" is #1146's own ruled residue. It could
    /// only ever LEAK: nothing tracks such a window, so no
    /// return ends its entry, and the compositor still hosts it,
    /// so no prune does either. Six immortal entries on the dev
    /// machine kept the 5 s census armed for the life of the
    /// process (the probe is on the issue).
    func seedAwayWindows() {
        let spaces = NativeSpaces.allSpaces()
        guard let census = desktopMemory.readCensus(spaces) else { return }
        let refs = Dictionary(
            eventLoop.runningApplications().map { ($0.pid, $0.ref) },
            uniquingKeysWith: { first, _ in first }
        )
        var seeded = 0
        for (id, host) in census.hosts.sorted(by: {
            $0.key.raw < $1.key.raw
        }) {
            guard census.isAway(id),
                host.isUp,
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
                nativeSpace: host.space,
                isUp: host.isUp
            )
            if state.rememberedSpace(of: id) == nil,
                let key = NativeSpaces.key(of: host.space, in: spaces),
                let space = desktopMemory.virtualSpaces[key],
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
    /// come back (#1207's rank); unfiled and parked entries
    /// excluded — a window minimized while away is not reached,
    /// as one minimized here is not.
    func awayMembers(of space: SpaceID) -> [WindowID] {
        state.awayWindows.values
            .filter { $0.isUp && state.rememberedSpace(of: $0.id) == space }
            .map(\.id)
            .sorted {
                (state.departedSlots[$0] ?? .max, $0.raw)
                    < (state.departedSlots[$1] ?? .max, $1.raw)
            }
    }

    /// An app's away windows, spaces in canonical order and by
    /// rank inside each; parked and unfiled entries last, by id.
    /// `bundleID` arrives lowercased (the command's
    /// normalization).
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
    /// (`Space.insert(_:rank:ranks:)`), so the Open-or-Focus ring
    /// walks the row as the return will rebuild it. NOT for a bar
    /// derivation: the bar draws the Desktop in front of the user
    /// (#1228).
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
            members.insert(
                id,
                at: Space.rankedInsertionIndex(
                    rank: rank,
                    in: members,
                    ranks: state.departedSlots
                )
            )
        }
        return members
    }
}
