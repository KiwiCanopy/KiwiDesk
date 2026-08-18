import CoreGraphics

// MARK: - App-enforced size bounds (#677)

/// The engine's half of the size-bound machinery: how `retile`
/// consults the learner, and the invalidation surface the event
/// flow calls. The learning ladder itself is `SizeBoundLearner`;
/// what a learned bound means is `EffectiveSizeBound`.
extension TilingEngine {
    /// Whether a retile target that fails the plain skip check
    /// is nevertheless "already there": the window's position
    /// matches, and every size axis off target is re-asking an
    /// ask the app has twice refused, with the window at the
    /// learned answer. Consulted un-forced only — an explicit
    /// apply keeps its contract of re-issuing everything.
    func sizeBoundExplains(
        _ id: WindowID,
        current: CGRect,
        target: CGRect
    ) -> Bool {
        guard
            abs(current.minX - target.minX)
                <= Self.retileTolerance,
            abs(current.minY - target.minY)
                <= Self.retileTolerance,
            let bound = boundLearner.bound(for: id)
        else { return false }
        return bound.explains(
            currentSize: current.size,
            targetSize: target.size
        )
    }

    /// The confirmed bound for one window, nil while unproven.
    /// Read by the layout-context threading (`layoutInput`) and
    /// the overlay pin below.
    func sizeBound(for id: WindowID) -> EffectiveSizeBound? {
        boundLearner.bound(for: id)
    }

    /// Every confirmed bound for the given windows — the
    /// layout-context input (#677): a layout may consume a
    /// bound as the window's own span (scrolling re-packs the
    /// row, monocle centers) so the residue the refusal leaves
    /// is placed deliberately instead of piling at the slot
    /// origin.
    func sizeBounds(
        for windows: [WindowID]
    ) -> [WindowID: EffectiveSizeBound] {
        var result: [WindowID: EffectiveSizeBound] = [:]
        for id in windows {
            if let bound = boundLearner.bound(for: id) {
                result[id] = bound
            }
        }
        return result
    }

    /// Drops everything learned about a window. Called on a
    /// genuine (non-echo) resize — the user or the app itself
    /// changed the size, so the ledger is stale — and on
    /// destroy, because WindowIDs are reused (#152/#158).
    public func forgetSizeBound(_ id: WindowID) {
        boundLearner.forget(id)
    }

    /// Migrates the ledger across a native-tab rekey (#308),
    /// beside `rekeyStash`: same on-screen window, new id.
    public func rekeySizeBound(
        oldID: WindowID,
        newID: WindowID
    ) {
        boundLearner.rekey(old: oldID, new: newID)
    }
}
