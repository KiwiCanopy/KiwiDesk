import CoreGraphics

/// The engine's half of the corroboration probe (#1439): the
/// retile loop's one substitution door and the narration queue
/// `KiwiCore.retile` drains. Whether a probe is due, at what
/// span and with what baseline is the learner's decision
/// (`SizeBoundLearner+Probe`); this file threads it.
extension TilingEngine {
    struct CorroborationProbeIssue: Equatable {
        /// The layout's frame with the probed axis replaced.
        var frame: CGRect
        /// The pre-ask size where a trusted baseline lets one
        /// settled read complete the pair, else nil.
        var baseline: CGSize?
    }

    /// The probe to issue for `id` in place of `target`, nil
    /// when none is due; recorded for the log on the way out.
    func takeCorroborationProbe(
        _ id: WindowID,
        current: CGRect,
        target: CGRect
    ) -> CorroborationProbeIssue? {
        guard
            let issue = boundLearner.takeCorroborationProbe(
                id,
                current: current.size,
                target: target.size
            )
        else { return nil }
        issuedCorroborationProbes.append((id, issue.size))
        return CorroborationProbeIssue(
            frame: CGRect(origin: target.origin, size: issue.size),
            baseline: issue.baseline
        )
    }

    /// Drains the pass's issued probes — `takePendingBoundPlacement`'s
    /// shape, read by `KiwiCore.retile` after the pass.
    func takeIssuedCorroborationProbes() -> [(WindowID, CGSize)] {
        defer { issuedCorroborationProbes = [] }
        return issuedCorroborationProbes
    }

    /// Whether `id` performed its probe's ask and so owes the
    /// layout a re-ask (#1439) — read once per answer by
    /// `KiwiCore.observeSizeAnswer`; the retile-time channel
    /// re-asks in its own pass and clears it there.
    func takeProbeCompliance(_ id: WindowID) -> Bool {
        boundLearner.compliedProbes.remove(id) != nil
    }
}
