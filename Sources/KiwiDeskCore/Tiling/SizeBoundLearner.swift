import CoreGraphics

/// Learns app-enforced size bounds from the engine's own asks
/// (#677). `retile` records every size it issues
/// (`recordAsk`); at a later retile, once the window's
/// animation is done, the echo-fed state frame is the app's
/// answer to that ask (`observe`). The same ask refused with
/// the same answer **twice in a row** confirms an
/// `EffectiveSizeBound` for that axis; an ask the app complies
/// with clears the axis — candidate and any stale confirmed
/// bound its answer contradicts — so a lifted constraint heals
/// the moment the engine happens to ask past it again.
///
/// The engine gates `observe` on the window not animating AND
/// on its last set's echo grace having passed
/// (`TilingEngine.observeAppAnswer`): a pending echo makes
/// the stale pre-ask frame a *deterministic* repeated answer,
/// which two rapid retiles would confirm as a false bound —
/// so an ask inside its echo grace is not observed yet. The
/// grace is a time bound, not echo receipt, which is the first
/// accepted imprecision below.
///
/// Three accepted imprecisions, weighed rather than overlooked:
/// an app whose echo outlasts the grace (the stalled-app
/// class — its echo event also rides the #618 read queue) can
/// still present the stale pre-ask frame as a repeated answer
/// and confirm a false bound, narrowed by the grace and healed
/// by the same compliance and invalidation arms as every other
/// stale entry. A cancel mid-flight can seed one wrong
/// candidate (the frame observed is mid-travel, not an
/// answer); the next SAME-ASK observation overwrites it, and
/// one for an ask that never recurs persists until eviction or
/// forget — where its one consumer, the overlay pin, can
/// mis-render a single matching flight before the settle keys
/// re-read reality. And a constraint
/// that lifts with no resize event and no recurring ask stays
/// learned until an invalidation fires; the forget on every
/// genuine (non-echo) resize covers the real-world case, an
/// app re-bounding itself (System Settings switching panes).
///
/// Pure bookkeeping — no AX, no actors — so the confirm ladder
/// is unit-testable (`SizeBoundLearnerTests`).
struct SizeBoundLearner {
    /// Per-window, per-axis entry lists — the same shape twice,
    /// once for unconfirmed candidates and once for believed
    /// bounds. Entries are keyed by their asked span (matched
    /// within the quantum) and capped per axis, oldest evicted:
    /// different layouts ask different sizes, and a single slot
    /// per axis let them overwrite each other's ladder so the
    /// less-visited layout never converged (device QA,
    /// 2026-08-18).
    // Internal (not private): the invalidation half lives in
    // `SizeBoundLearner+Invalidation.swift`, split at the file
    // ceiling, and Swift private does not cross files.
    struct Ledger {
        var width: [EffectiveSizeBound.Axis] = []
        var height: [EffectiveSizeBound.Axis] = []
        var isEmpty: Bool { width.isEmpty && height.isEmpty }
    }

    /// Distinct asks remembered per axis. Sized WELL past the
    /// real producers — one ask per layout mode a window meets,
    /// and a window rarely tiles under more than three or
    /// four — because eviction is only a leak bound: evicting a
    /// candidate before its confirming re-encounter re-opens
    /// the starvation the per-ask shape exists to close
    /// (review, 2026-08-18), so the cap must never bind in
    /// ordinary use. Recurring past it costs a re-probe, not
    /// correctness.
    static let maxEntriesPerAxis = 8

    var lastAsks: [WindowID: CGSize] = [:]
    var candidates: [WindowID: Ledger] = [:]
    var bounds: [WindowID: Ledger] = [:]

    /// The size `retile` just issued for a window. Only the
    /// layout loop records — a stash park or float restore is
    /// not a layout ask, and learning from one would key a
    /// bound to a frame no layout will re-issue.
    mutating func recordAsk(_ id: WindowID, size: CGSize) {
        lastAsks[id] = size
    }

    /// The app's answer to the last recorded ask: the window's
    /// settled, echo-fed frame size. Callers gate on the
    /// window not animating — a mid-flight frame is travel,
    /// not an answer. Returns whether a BELIEVED entry was
    /// created or changed — the confirmation edge the caller
    /// answers with an immediate retile, so the residue is
    /// placed the moment the bound is known instead of at the
    /// next unrelated event (device QA, 2026-08-18: the
    /// re-pack "taking many visits" was this placement waiting
    /// for a retile that had no reason to come).
    @discardableResult
    mutating func observe(
        _ id: WindowID,
        currentSize: CGSize
    ) -> Bool {
        guard let asked = lastAsks[id] else { return false }
        // A non-positive span cannot be a real on-screen
        // window — it is a state frame no echo ever wrote (a
        // window created and never heard from again), not an
        // answer. Learning it would confirm a 0 pt "bound" and
        // collapse the slot.
        guard currentSize.width > 0, currentSize.height > 0
        else { return false }
        let widthConfirmed = observeAxis(
            id,
            asked: asked.width,
            current: currentSize.width,
            axis: \.width
        )
        let heightConfirmed = observeAxis(
            id,
            asked: asked.height,
            current: currentSize.height,
            axis: \.height
        )
        return widthConfirmed || heightConfirmed
    }

    /// The confirmed bound for a window, nil while unproven.
    /// The only view GEOMETRY may consume — the layouts'
    /// re-pack and centering, and the retile skip.
    func bound(for id: WindowID) -> EffectiveSizeBound? {
        bounds[id].map {
            EffectiveSizeBound(
                width: $0.width,
                height: $0.height
            )
        }
    }

    /// Whether a post-settle probe is worth an AX read
    /// (#677): the last ask exists, some axis of it is off the
    /// window's current state frame (a refusal, or an echo not
    /// yet landed), and that axis is not already believed. The
    /// common settle — a complying window whose echo landed —
    /// answers false, so probing costs nothing there.
    func wantsProbe(
        _ id: WindowID,
        currentSize: CGSize
    ) -> Bool {
        guard let asked = lastAsks[id] else { return false }
        let believed = bound(for: id)
        let widthDone =
            EffectiveSizeBound.matches(
                currentSize.width,
                asked.width
            )
            || believed?.consumedWidth(asking: asked.width)
                != nil
        let heightDone =
            EffectiveSizeBound.matches(
                currentSize.height,
                asked.height
            )
            || believed?.consumedHeight(asking: asked.height)
                != nil
        return !(widthDone && heightDone)
    }

    /// The unconfirmed candidates, in the same shape — for the
    /// overlay pin ONLY (#677 device QA): rendering may trust a
    /// single refusal because a wrong render self-corrects at
    /// settle, so the ring stops riding out on the second probe
    /// instead of the third. Geometry must not consume this — a
    /// wrong candidate would misplace real windows.
    func candidateBound(
        for id: WindowID
    ) -> EffectiveSizeBound? {
        candidates[id].map {
            EffectiveSizeBound(
                width: $0.width,
                height: $0.height
            )
        }
    }

    /// Drops everything learned about a window: it resized for
    /// a reason that was not our ask (user, or the app
    /// re-bounding itself), so the ledger describes a window
    /// that no longer exists. Also the destroy path — WindowIDs
    /// are reused (#152/#158).
    mutating func forget(_ id: WindowID) {
        lastAsks[id] = nil
        candidates[id] = nil
        bounds[id] = nil
    }

    /// Migrates the ledger across a native-tab rekey (#308) —
    /// the `rekeyStash` precedent: same on-screen window, new
    /// id, same app-side constraints.
    mutating func rekey(old: WindowID, new: WindowID) {
        if let asks = lastAsks.removeValue(forKey: old) {
            lastAsks[new] = asks
        }
        if let cands = candidates.removeValue(forKey: old) {
            candidates[new] = cands
        }
        if let bound = bounds.removeValue(forKey: old) {
            bounds[new] = bound
        }
    }

    private mutating func observeAxis(
        _ id: WindowID,
        asked: CGFloat,
        current: CGFloat,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> Bool {
        var confirmed = false
        if EffectiveSizeBound.matches(current, asked) {
            complied(id, asked: asked, axis: axis)
            return false
        }
        var candidateEntries =
            candidates[id]?[keyPath: axis] ?? []
        if let index = candidateEntries.firstIndex(where: {
            EffectiveSizeBound.matches($0.asked, asked)
        }) {
            let prior = candidateEntries[index]
            if EffectiveSizeBound.matches(
                prior.answered,
                current
            ) {
                // Twice in a row: the entry is believed.
                confirmed = promote(
                    id,
                    asked: asked,
                    answered: current,
                    axis: axis
                )
                candidateEntries.remove(at: index)
            } else {
                // Same ask, different answer: restart this
                // ask's ladder on the newest observation.
                candidateEntries[index] =
                    EffectiveSizeBound.Axis(
                        asked: asked,
                        answered: current
                    )
            }
        } else {
            candidateEntries.append(
                EffectiveSizeBound.Axis(
                    asked: asked,
                    answered: current
                )
            )
            if candidateEntries.count > Self.maxEntriesPerAxis {
                candidateEntries.removeFirst()
            }
        }
        writeCandidates(
            id,
            entries: candidateEntries,
            axis: axis
        )
        return confirmed
    }

    /// Returns whether the believed ledger actually CHANGED —
    /// re-promoting an identical entry is not a confirmation
    /// edge, which is what keeps the caller's answer (an
    /// immediate retile) from looping on its own echoes.
    private mutating func promote(
        _ id: WindowID,
        asked: CGFloat,
        answered: CGFloat,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> Bool {
        var entries = bounds[id]?[keyPath: axis] ?? []
        let entry = EffectiveSizeBound.Axis(
            asked: asked,
            answered: answered
        )
        if let index = entries.firstIndex(where: {
            EffectiveSizeBound.matches($0.asked, asked)
        }) {
            if EffectiveSizeBound.matches(
                entries[index].answered,
                answered
            ) {
                return false
            }
            entries[index] = entry
        } else {
            entries.append(entry)
            if entries.count > Self.maxEntriesPerAxis {
                entries.removeFirst()
            }
        }
        writeBounds(id, entries: entries, axis: axis)
        return true
    }

}
