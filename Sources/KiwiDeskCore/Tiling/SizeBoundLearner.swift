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
/// answer), and the next settled observation overwrites it.
/// And a constraint
/// that lifts with no resize event and no recurring ask stays
/// learned until an invalidation fires; the forget on every
/// genuine (non-echo) resize covers the real-world case, an
/// app re-bounding itself (System Settings switching panes).
///
/// Pure bookkeeping — no AX, no actors — so the confirm ladder
/// is unit-testable (`SizeBoundLearnerTests`).
struct SizeBoundLearner {
    private struct AxisCandidate: Equatable {
        var asked: CGFloat
        var answered: CGFloat
    }

    private struct Candidates {
        var width: AxisCandidate?
        var height: AxisCandidate?
        var isEmpty: Bool { width == nil && height == nil }
    }

    private var lastAsks: [WindowID: CGSize] = [:]
    private var candidates: [WindowID: Candidates] = [:]
    private var bounds: [WindowID: EffectiveSizeBound] = [:]

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
    /// not an answer.
    mutating func observe(_ id: WindowID, currentSize: CGSize) {
        guard let asked = lastAsks[id] else { return }
        // A non-positive span cannot be a real on-screen
        // window — it is a state frame no echo ever wrote (a
        // window created and never heard from again), not an
        // answer. Learning it would confirm a 0 pt "bound" and
        // collapse the slot.
        guard currentSize.width > 0, currentSize.height > 0
        else { return }
        observeAxis(
            id,
            asked: asked.width,
            current: currentSize.width,
            candidate: \.width,
            bound: \.width
        )
        observeAxis(
            id,
            asked: asked.height,
            current: currentSize.height,
            candidate: \.height,
            bound: \.height
        )
    }

    /// The confirmed bound for a window, nil while unproven.
    func bound(for id: WindowID) -> EffectiveSizeBound? {
        bounds[id]
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
        candidate: WritableKeyPath<Candidates, AxisCandidate?>,
        bound: WritableKeyPath<EffectiveSizeBound, EffectiveSizeBound.Axis?>
    ) {
        if EffectiveSizeBound.matches(current, asked) {
            complied(
                id,
                asked: asked,
                candidate: candidate,
                bound: bound
            )
            return
        }
        let observed = AxisCandidate(
            asked: asked,
            answered: current
        )
        if let prior = candidates[id]?[keyPath: candidate],
            EffectiveSizeBound.matches(prior.asked, asked),
            EffectiveSizeBound.matches(prior.answered, current)
        {
            var entry = bounds[id] ?? EffectiveSizeBound()
            entry[keyPath: bound] = EffectiveSizeBound.Axis(
                asked: asked,
                answered: current
            )
            bounds[id] = entry
            candidates[id]?[keyPath: candidate] = nil
            cleanUpCandidates(id)
        } else {
            var entry = candidates[id] ?? Candidates()
            entry[keyPath: candidate] = observed
            candidates[id] = entry
        }
    }

    /// The app performed this axis's ask. Clear the candidate,
    /// and clear a confirmed bound the compliance contradicts:
    /// a ceiling (`answered < asked`) is falsified by a
    /// complied ask above its answer, a floor by one below —
    /// the constraint lifted, and keeping the bound would let a
    /// stale skip pin the window at a size the app no longer
    /// insists on.
    private mutating func complied(
        _ id: WindowID,
        asked: CGFloat,
        candidate: WritableKeyPath<Candidates, AxisCandidate?>,
        bound: WritableKeyPath<EffectiveSizeBound, EffectiveSizeBound.Axis?>
    ) {
        candidates[id]?[keyPath: candidate] = nil
        cleanUpCandidates(id)
        guard var entry = bounds[id],
            let axis = entry[keyPath: bound]
        else { return }
        let tolerance = EffectiveSizeBound.matchTolerance
        let ceiling = axis.answered < axis.asked
        let contradicts =
            ceiling
            ? asked > axis.answered + tolerance
            : asked < axis.answered - tolerance
        guard contradicts else { return }
        entry[keyPath: bound] = nil
        bounds[id] = entry.isEmpty ? nil : entry
    }

    private mutating func cleanUpCandidates(_ id: WindowID) {
        if candidates[id]?.isEmpty == true {
            candidates[id] = nil
        }
    }
}
