import CoreGraphics

/// The ledger's invalidation half, split at the file ceiling:
/// what UNLEARNS — the compliance sweep and its cross-ask
/// trade, the late-echo classifier the forget gate consults,
/// and the forget/rekey lifecycle. The learning ladder stays
/// in `SizeBoundLearner.swift`.
extension SizeBoundLearner {
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

    /// Whether a reported size is one this ledger already
    /// explains — the late-delivered echo of our own ask (the
    /// answer we learned, or the ask itself complied late),
    /// never evidence that someone ELSE resized the window. The
    /// #618 read queue can deliver an echo past the applier's
    /// grace, and classifying that as a genuine resize wiped
    /// the ledger over and over (device QA, 2026-08-18: monocle
    /// never accumulated two observations).
    func explainsResize(
        _ id: WindowID,
        size: CGSize
    ) -> Bool {
        axisResizeExplained(
            id,
            span: size.width,
            ask: lastAsks[id]?.size.width,
            axis: \.width
        )
            && axisResizeExplained(
                id,
                span: size.height,
                ask: lastAsks[id]?.size.height,
                axis: \.height
            )
    }

    private func axisResizeExplained(
        _ id: WindowID,
        span: CGFloat,
        ask: CGFloat?,
        axis: KeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> Bool {
        if let ask, EffectiveSizeBound.matches(ask, span) {
            return true
        }
        let known =
            (bounds[id]?[keyPath: axis] ?? [])
            + (candidates[id]?[keyPath: axis] ?? [])
        return known.contains {
            EffectiveSizeBound.matches($0.answered, span)
        }
    }

    /// The app performed this axis's ask. Clear the ask's
    /// candidate, and clear every believed entry the compliance
    /// contradicts: a ceiling (`answered < asked`) is falsified
    /// by a complied ask above its answer, a floor by one
    /// below — the constraint lifted, and keeping the entry
    /// would let a stale skip pin the window at a size the app
    /// no longer insists on. This sweep deliberately reasons
    /// ACROSS asks — the one place the per-ask model does —
    /// and that is a chosen trade: for a grid-snapping app a
    /// compliance at 904 clears a still-valid (900→896) entry
    /// and that ask re-probes once when it recurs, which is
    /// cheap; the alternative, keeping an entry a compliance
    /// contradicts, risks pinning a window at a size its app
    /// stopped insisting on, which is the stale-skip failure
    /// this ledger must never ship (review, 2026-08-18).
    mutating func complied(
        _ id: WindowID,
        asked: CGFloat,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) {
        if var candidateEntries = candidates[id]?[
            keyPath: axis
        ] {
            candidateEntries.removeAll {
                EffectiveSizeBound.matches($0.asked, asked)
            }
            writeCandidates(
                id,
                entries: candidateEntries,
                axis: axis
            )
        }
        guard var entries = bounds[id]?[keyPath: axis]
        else { return }
        let tolerance = EffectiveSizeBound.matchTolerance
        entries.removeAll { entry in
            let ceiling = entry.answered < entry.asked
            return ceiling
                ? asked > entry.answered + tolerance
                : asked < entry.answered - tolerance
        }
        writeBounds(id, entries: entries, axis: axis)
    }

    mutating func writeCandidates(
        _ id: WindowID,
        entries: [EffectiveSizeBound.Axis],
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) {
        var ledger = candidates[id] ?? Ledger()
        ledger[keyPath: axis] = entries
        candidates[id] = ledger.isEmpty ? nil : ledger
    }

    mutating func writeBounds(
        _ id: WindowID,
        entries: [EffectiveSizeBound.Axis],
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) {
        var ledger = bounds[id] ?? Ledger()
        ledger[keyPath: axis] = entries
        bounds[id] = ledger.isEmpty ? nil : ledger
    }
}
