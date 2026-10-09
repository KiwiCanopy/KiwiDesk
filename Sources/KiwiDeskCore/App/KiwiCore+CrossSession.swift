import Foundation

/// The cross-session restore (#1385 ruling 2026-10-09): after a
/// restart of the Mac or a logout, the snapshot's window ids name
/// nothing, so the windows macOS reopens are paired with its
/// records by `CrossSessionMatch` — at boot, at each arrival and
/// once titles settle — and never by id. One clock: the passes are
/// `deferred` tasks, never a wall-clock reading.
extension KiwiCore {
    typealias CrossSessionPair = (
        window: WindowID, record: CrossSessionMatch.Record
    )

    /// Arms the match over the snapshot a logout's freeze wrote
    /// and pairs what the boot scan tracked; returns those pairs
    /// re-keyed for the boot replay, or nil when no record carries
    /// a key (an older build's file).
    func armCrossSessionMatch(_ snapshot: StateSnapshot) -> StateSnapshot? {
        var match = CrossSessionMatch(
            snapshot,
            arrangement: liveArrangement
        ) { state.workspaces[$0] != nil }
        let waiting = match.pending.count
        guard waiting > 0 else {
            onLog("cross-session: no window carries a key; none matched")
            return nil
        }
        let pairs = match.pairs(crossSessionCandidates())
        match.commit(pairs)
        state.crossSession = match
        onLog(
            "cross-session: \(pairs.count) of \(waiting) window(s) "
                + "matched at boot; open "
                + "\(Int(CrossSessionMatch.bound))s for the rest"
        )
        logCrossSession(pairs, phase: "boot")
        deferred.schedule(
            .crossSessionSettle,
            after: .seconds(CrossSessionMatch.titleSettle)
        ) { [weak self] in self?.crossSessionSettlePass() }
        deferred.schedule(
            .crossSessionClose,
            after: .seconds(CrossSessionMatch.bound)
        ) { [weak self] in self?.closeCrossSessionMatch() }
        let ids = pairs.map { ($0.record.id, $0.window) }
        return snapshot.rekeyed(
            Dictionary(ids, uniquingKeysWith: { first, _ in first })
        )
    }

    /// An arrival while the match is open: a pair files the window
    /// in its Space before the create fold, as a late window of a
    /// same-session restore is filed (#1362). It lands where a new
    /// window of that Space would, not in its old slot.
    func claimCrossSessionArrival(_ window: ManagedWindow) {
        guard crossSessionStillApplies(),
            state.windows[window.id] == nil,
            state.rememberedSpaces[window.id] == nil,
            !window.isTransientOverlay,
            let app = window.appBundleID
        else { return }
        let arriving = CrossSessionMatch.Candidate(
            id: window.id,
            app: app,
            title: window.title
        )
        let others = crossSessionCandidates().filter { $0.app == app }
        guard
            let pair = state.crossSession.pairs(others + [arriving])
                .first(where: { $0.window == window.id }),
            state.workspaces[pair.record.space] != nil
        else { return }
        state.crossSession.commit([pair])
        state.remember(window.id, in: pair.record.space)
        // A corner rides only for the float it carries (#1864).
        if !tiler.looksStashed(pair.record.frame) || pair.record.floating {
            state.restoredFrames[window.id] = .init(
                frame: pair.record.frame,
                floating: pair.record.floating
            )
        }
        logCrossSession([pair], phase: "arrival")
    }

    /// The title pass, `titleSettle` after arming: tracked windows
    /// still unpaired are re-filed quietly through the one
    /// membership door — no focus, no event, one retile. The
    /// focused window is paired but left where it is; a sticky one
    /// and one a user verb filed (`placed`) are never paired.
    func crossSessionSettlePass() {
        guard crossSessionStillApplies() else { return }
        state.crossSession.settle()
        let pairs = state.crossSession.pairs(crossSessionCandidates())
        state.crossSession.commit(pairs)
        logCrossSession(pairs, phase: "settle")
        var moved = false
        for pair in pairs {
            let from = state.workspaces.space(of: pair.window)
            // The window the user is in stays where it is.
            guard state.workspaces[pair.record.space] != nil,
                from != pair.record.space,
                pair.window != state.workspaces.lastFocused
            else { continue }
            fileMembership(
                pair.window,
                into: pair.record.space,
                from: from,
                restoring: true
            )
            restoreCarriedFloat(pair)
            moved = true
        }
        if moved { retile() }
    }

    /// A title-pass pair's carried hand float (#1864): floated, and
    /// its record's frame seeded for the stash to deliver — never a
    /// corner — as the boot replay and an arrival pay theirs.
    private func restoreCarriedFloat(_ pair: CrossSessionPair) {
        guard pair.record.floating else { return }
        state.floatByHand(pair.window)
        if !tiler.looksStashed(pair.record.frame) {
            tiler.seedStash(pair.window, frame: pair.record.frame)
        }
    }

    /// Whether the match is open under the arrangement it armed
    /// in. A Load, a Desktop-bound switch or a monitor change in
    /// between closes it: its records name another arrangement's
    /// Spaces, and that switch's hold rules own the windows now.
    private func crossSessionStillApplies() -> Bool {
        guard state.crossSession.isOpen else { return false }
        guard state.crossSession.arrangement != liveArrangement else {
            return true
        }
        let missed = state.crossSession.close()
        onLog(
            "cross-session: the arrangement changed; closed with "
                + "\(missed) window(s) unpaired"
        )
        return false
    }

    /// Ends the match at its bound.
    func closeCrossSessionMatch() {
        let missed = state.crossSession.close()
        guard missed > 0 else { return }
        onLog("cross-session: closed; \(missed) window(s) never paired")
    }

    /// Every tracked window the match may still take: never a
    /// sticky one or a transient overlay.
    private func crossSessionCandidates() -> [CrossSessionMatch.Candidate] {
        state.windows.all.compactMap { window in
            guard !window.isTransientOverlay,
                window.stickyScope == .none,
                let app = window.appBundleID
            else { return nil }
            return .init(id: window.id, app: app, title: window.title)
        }
    }

    /// One line per pair; titles stay out of the unified log.
    private func logCrossSession(
        _ pairs: [CrossSessionPair],
        phase: String
    ) {
        for pair in pairs {
            onLog(
                "cross-session: phase=\(phase) "
                    + "w\(pair.record.id.raw)→w\(pair.window.raw) "
                    + "app=\(pair.record.app) "
                    + "space=\(pair.record.space.raw)"
            )
        }
    }
}
