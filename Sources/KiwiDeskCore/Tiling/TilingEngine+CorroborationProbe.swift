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
        /// Whether a new issue went out; false where the frame
        /// only carries an issue already out (#2758).
        var fresh: Bool
        /// The learner's verdicts on a carried frame, as
        /// `SizeBoundLearner.ProbeIssue` states them.
        var sameQuestion = false
        /// See `sameQuestion`.
        var alreadyOut = false
    }

    /// The probe to issue for `id` in place of `target`, nil when
    /// none is due; a new issue is recorded for the log on the way
    /// out. `keepsIssueOut` carries an issue already out (#2758).
    func takeCorroborationProbe(
        _ id: WindowID,
        current: CGRect,
        target: CGRect,
        keepsIssueOut: Bool
    ) -> CorroborationProbeIssue? {
        guard
            let issue = boundLearner.takeCorroborationProbe(
                id,
                current: current.size,
                target: target.size,
                serving: target,
                keepsIssueOut: keepsIssueOut
            )
        else { return nil }
        if issue.fresh {
            issuedCorroborationProbes.append((id, issue.size))
        }
        return CorroborationProbeIssue(
            frame: CGRect(origin: target.origin, size: issue.size),
            baseline: issue.baseline,
            fresh: issue.fresh,
            sameQuestion: issue.sameQuestion,
            alreadyOut: issue.alreadyOut
        )
    }

    /// Drains the pass's issued probes — `takePendingBoundPlacement`'s
    /// shape, read by `KiwiCore.retile` after the pass.
    func takeIssuedCorroborationProbes() -> [(WindowID, CGSize)] {
        defer { issuedCorroborationProbes = [] }
        return issuedCorroborationProbes
    }
}
