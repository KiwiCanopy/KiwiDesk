import CoreGraphics

/// The issued corroboration probe still awaiting its settled
/// answer (#1439, #2758): the layout loop holds a frame that would
/// only re-ask what the probe stands in for, or the probe's ask is
/// superseded before the app answers it and the pair never forms.
/// Pure bookkeeping, like the ledger it reads.
extension SizeBoundLearner {
    private enum InFlightAxis {
        /// The issue in flight is the last ask and `target`
        /// re-asks a span the anchor answers.
        case standsIn(slot: CGRect?)
        /// Nothing in flight here; `target` keeps the last ask.
        case unchanged
        /// `target` asks something else.
        case changed
    }

    /// Whether `target` would only supersede `id`'s probe in
    /// flight, and if so marks the probe held so its answer owes
    /// the placement. On a probed axis `target` re-asks a span
    /// the anchor answers, on the other the last ask's own, and
    /// it lies in the slot the issue stood in for: at the slot's
    /// origin, or inside it where the layout reshaped the window
    /// (a residue centred, a park re-anchored at the answer).
    mutating func holdForProbe(_ id: WindowID, target: CGRect) -> Bool {
        guard let asked = lastAsks[id]?.size, let ledger = probes[id]
        else { return false }
        let axes = [
            inFlight(
                ledger.width,
                asked: asked.width,
                target: target.width
            ),
            inFlight(
                ledger.height,
                asked: asked.height,
                target: target.height
            ),
        ]
        var slot: CGRect?
        var standsIn = false
        for axis in axes {
            switch axis {
            case .standsIn(let issued):
                standsIn = true
                slot = slot ?? issued
            case .unchanged: break
            case .changed: return false
            }
        }
        guard standsIn, let slot, Self.sameSlot(target, slot)
        else { return false }
        probes[id]?.width.pending?.held = true
        probes[id]?.height.pending?.held = true
        return true
    }

    /// A settled read of `asked`: every issue in flight on it is
    /// answered. Returns whether one of them had a frame held.
    mutating func noteProbeAnswered(
        _ id: WindowID,
        asked: CGSize
    ) -> Bool {
        let width = answerProbe(id, \.width, asked: asked.width)
        let height = answerProbe(id, \.height, asked: asked.height)
        return width || height
    }

    private mutating func answerProbe(
        _ id: WindowID,
        _ slot: WritableKeyPath<ProbeLedger, AxisProbes>,
        asked: CGFloat
    ) -> Bool {
        guard var probe = probes[id]?[keyPath: slot].pending,
            probe.isInFlight(lastAsked: asked)
        else { return false }
        let held = probe.held
        probe.answeredIssues = probe.issues
        probe.held = false
        probes[id]?[keyPath: slot].pending = probe
        return held
    }

    private func inFlight(
        _ axis: AxisProbes,
        asked: CGFloat,
        target: CGFloat
    ) -> InFlightAxis {
        if let probe = axis.pending, probe.isInFlight(lastAsked: asked) {
            return probe.standsIn(for: target)
                ? .standsIn(slot: probe.slot) : .changed
        }
        return EffectiveSizeBound.matches(asked, target)
            ? .unchanged : .changed
    }

    private static func sameSlot(_ target: CGRect, _ slot: CGRect) -> Bool {
        let reshaped =
            !EffectiveSizeBound.matches(target.width, slot.width)
            || !EffectiveSizeBound.matches(target.height, slot.height)
        guard reshaped else {
            return EffectiveSizeBound.matches(target.minX, slot.minX)
                && EffectiveSizeBound.matches(target.minY, slot.minY)
        }
        return slot.contains(CGPoint(x: target.midX, y: target.midY))
    }
}
