import CoreGraphics

/// The answer half of an issue out (#1439, #2758): a settled read
/// of the issue's own ask answers it, which ends the take door's
/// carrying and owes the placement of a frame bent to it. Pure
/// bookkeeping, like the ledger it reads.
extension SizeBoundLearner {
    /// A settled read of `asked`: every issue in flight on it is
    /// answered. Returns whether one of them had a frame bent to
    /// it, which the caller then owes a placement.
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
}
