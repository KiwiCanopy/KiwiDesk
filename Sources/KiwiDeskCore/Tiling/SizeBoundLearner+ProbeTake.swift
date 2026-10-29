import CoreGraphics

/// The corroboration probe's one door into the retile loop (#1439,
/// #2758): what the loop issues in place of the layout's target. A
/// new issue where one is due, and on an ordinary pass the issue
/// still out on every axis whose span the target still asks, so no
/// layout frame overwrites a question before a settled read answers
/// it. The probe's contract is `SizeBoundLearner+Probe`.
extension SizeBoundLearner {
    /// What to issue in place of the layout's `target` on this
    /// pass, nil when nothing is due. A probe stands in only where
    /// the layout's span is one the anchor already answers — its
    /// ask or its answer — and never displaces any other. A new
    /// issue goes out at most `maxProbeIssues` times; with
    /// `keepsIssueOut` (an ordinary pass) an issue out is carried
    /// instead, re-sent at most `maxProbeResends` times after an
    /// ordinary ask overwrote it. Retired when the anchor is gone,
    /// when the axis corroborated meanwhile, once the issues are
    /// spent and answered, and once the re-sends are spent.
    mutating func takeCorroborationProbe(
        _ id: WindowID,
        current: CGSize,
        target: CGSize,
        keepsIssueOut: Bool = false
    ) -> ProbeIssue? {
        guard var ledger = probes[id] else { return nil }
        var size = target
        var trusted = false
        var fresh = false
        var residue = true
        let last = lastAsks[id]?.size
        if let taken = takeProbeAxis(
            &ledger,
            slot: \.width,
            entries: bounds[id]?.width ?? [],
            candidates: candidates[id]?.width ?? [],
            current: current.width,
            target: target.width,
            lastAsked: last?.width,
            keepsIssueOut: keepsIssueOut,
            trusted: &trusted
        ) {
            size.width = taken.span
            fresh = fresh || taken.fresh
            residue = residue && taken.residue
        }
        if let taken = takeProbeAxis(
            &ledger,
            slot: \.height,
            entries: bounds[id]?.height ?? [],
            candidates: candidates[id]?.height ?? [],
            current: current.height,
            target: target.height,
            lastAsked: last?.height,
            keepsIssueOut: keepsIssueOut,
            trusted: &trusted
        ) {
            size.height = taken.span
            fresh = fresh || taken.fresh
            residue = residue && taken.residue
        }
        probes[id] = ledger
        guard size != target else { return nil }
        let alreadyOut =
            !fresh
            && last.map {
                EffectiveSizeBound.matches($0.width, size.width)
                    && EffectiveSizeBound.matches($0.height, size.height)
            } == true
        return ProbeIssue(
            size: size,
            baseline: trusted ? current : nil,
            fresh: fresh,
            alreadyOut: alreadyOut,
            residue: alreadyOut && residue
        )
    }

    private mutating func takeProbeAxis(
        _ ledger: inout ProbeLedger,
        slot: WritableKeyPath<ProbeLedger, AxisProbes>,
        entries: [EffectiveSizeBound.Axis],
        candidates: [EffectiveSizeBound.Axis],
        current: CGFloat,
        target: CGFloat,
        lastAsked: CGFloat?,
        keepsIssueOut: Bool,
        trusted: inout Bool
    ) -> (span: CGFloat, fresh: Bool, residue: Bool)? {
        guard var probe = ledger[keyPath: slot].pending
        else { return nil }
        let anchorStands = entries.contains {
            EffectiveSizeBound.matches($0.asked, probe.anchor.asked)
                && EffectiveSizeBound.matches(
                    $0.answered,
                    probe.anchor.answered
                )
        }
        let answered = candidates.contains {
            EffectiveSizeBound.matches($0.asked, probe.asked)
        }
        guard anchorStands,
            !Self.corroborates(entries, floor: probe.isFloor),
            probe.issues < Self.maxProbeIssues || probe.isOut
        else {
            Self.retire(&ledger[keyPath: slot])
            return nil
        }
        guard probe.standsIn(for: target) else { return nil }
        // An issue out stays out until a settled read answers it;
        // a first answer's candidate is the re-issue's cue.
        if probe.isOut,
            !answered || probe.issues >= Self.maxProbeIssues
        {
            guard keepsIssueOut else { return nil }
            if !probe.isInFlight(lastAsked: lastAsked) {
                // Overwritten before its answer: re-sent, bounded.
                guard probe.resends < Self.maxProbeResends else {
                    Self.retire(&ledger[keyPath: slot])
                    return nil
                }
                probe.resends += 1
            }
            probe.held = true
            ledger[keyPath: slot].pending = probe
            let residue =
                EffectiveSizeBound.matches(target, probe.anchor.answered)
                && !EffectiveSizeBound.matches(target, probe.anchor.asked)
            return (probe.asked, false, residue)
        }
        guard probe.issues < Self.maxProbeIssues,
            probe.issues == 0 || answered
        else { return nil }
        // A trusted baseline needs the frame to still be the
        // anchor's answer — anything else moved it since the
        // read that earned the trust.
        if probe.baselineTrusted,
            EffectiveSizeBound.matches(current, probe.expected)
        {
            trusted = true
        }
        probe.baselineTrusted = false
        probe.issues += 1
        probe.resends = 0
        probe.held = false
        ledger[keyPath: slot].pending = probe
        return (probe.asked, true, false)
    }
}
