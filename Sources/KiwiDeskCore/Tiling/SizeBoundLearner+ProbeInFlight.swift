import CoreGraphics

/// The issued corroboration probe still awaiting its answer
/// (#1439, #2758): the engine's layout loop holds a frame that
/// would only re-ask what the probe stands in for, or the
/// probe's ask is superseded before the app answers it and the
/// pair never forms. Pure bookkeeping, like the ledger it reads.
extension SizeBoundLearner {
    private enum InFlightAxis {
        /// The probe is the last ask and `target` re-asks the
        /// anchor's ask or answer on this axis.
        case standsIn
        /// No probe in flight here; `target` keeps the last ask.
        case unchanged
        /// `target` asks something else.
        case changed
    }

    /// Whether `id`'s last ask is an issued, unanswered
    /// corroboration probe and `target` re-asks only the spans
    /// it stands in for: on a probed axis the anchor's ask or
    /// answer, on the other the last ask's own span. A probe
    /// whose first answer seeded a candidate is answered, and a
    /// retired one is gone, so neither holds a frame.
    func probeInFlight(_ id: WindowID, target: CGSize) -> Bool {
        guard let asked = lastAsks[id]?.size, let ledger = probes[id]
        else { return false }
        let axes = [
            inFlight(
                ledger.width,
                candidates: candidates[id]?.width ?? [],
                asked: asked.width,
                target: target.width
            ),
            inFlight(
                ledger.height,
                candidates: candidates[id]?.height ?? [],
                asked: asked.height,
                target: target.height
            ),
        ]
        return axes.contains(.standsIn) && !axes.contains(.changed)
    }

    private func inFlight(
        _ axis: AxisProbes,
        candidates: [EffectiveSizeBound.Axis],
        asked: CGFloat,
        target: CGFloat
    ) -> InFlightAxis {
        if let probe = axis.pending, probe.issues > 0,
            EffectiveSizeBound.matches(probe.asked, asked),
            !candidates.contains(where: {
                EffectiveSizeBound.matches($0.asked, probe.asked)
            })
        {
            let standsIn =
                EffectiveSizeBound.matches(target, probe.anchor.asked)
                || EffectiveSizeBound.matches(
                    target,
                    probe.anchor.answered
                )
            return standsIn ? .standsIn : .changed
        }
        return EffectiveSizeBound.matches(asked, target)
            ? .unchanged : .changed
    }
}
