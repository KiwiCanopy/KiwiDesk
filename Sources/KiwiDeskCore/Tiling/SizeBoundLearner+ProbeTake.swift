import CoreGraphics

/// The corroboration probe's take door (#1439): what the retile
/// loop issues in place of the layout's target. The probe's
/// contract is `SizeBoundLearner+Probe`; the hold that protects an
/// issue in flight is `SizeBoundLearner+ProbeInFlight` (#2758).
extension SizeBoundLearner {
    /// The engine's door: what to issue in place of the layout's
    /// `target` on this pass, nil when nothing is due. Due only
    /// where the layout's span is one the anchor already answers
    /// — its ask or its answer — since the retile would skip that
    /// as explained and the probe may not displace any other;
    /// retired when the anchor is gone, when the axis
    /// corroborated meanwhile, and once `maxProbeIssues` are out.
    mutating func takeCorroborationProbe(
        _ id: WindowID,
        current: CGSize,
        target: CGSize,
        slot frame: CGRect? = nil
    ) -> ProbeIssue? {
        guard var ledger = probes[id] else { return nil }
        var size = target
        var trusted = false
        let last = lastAsks[id]?.size
        if let asked = takeProbeAxis(
            &ledger,
            slot: \.width,
            entries: bounds[id]?.width ?? [],
            candidates: candidates[id]?.width ?? [],
            current: current.width,
            target: target.width,
            lastAsked: last?.width,
            frame: frame,
            trusted: &trusted
        ) {
            size.width = asked
        }
        if let asked = takeProbeAxis(
            &ledger,
            slot: \.height,
            entries: bounds[id]?.height ?? [],
            candidates: candidates[id]?.height ?? [],
            current: current.height,
            target: target.height,
            lastAsked: last?.height,
            frame: frame,
            trusted: &trusted
        ) {
            size.height = asked
        }
        guard size != target else {
            probes[id] = ledger
            return nil
        }
        // #2758: an issue still in flight on the axis not taken
        // rides along rather than being superseded.
        if size.width == target.width,
            Self.carry(
                &ledger.width,
                asked: last?.width,
                target: target.width,
                into: &size.width
            )
        {
            ledger.width.pending?.slot = frame
        }
        if size.height == target.height,
            Self.carry(
                &ledger.height,
                asked: last?.height,
                target: target.height,
                into: &size.height
            )
        {
            ledger.height.pending?.slot = frame
        }
        probes[id] = ledger
        return ProbeIssue(
            size: size,
            baseline: trusted ? current : nil
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
        frame: CGRect?,
        trusted: inout Bool
    ) -> CGFloat? {
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
        // An issue stays pending until a settled read answers it,
        // and one an ordinary ask overwrote first is re-sent in
        // place when the layout asks its span again (#2758).
        let unanswered = probe.answeredIssues < probe.issues
        let superseded =
            unanswered && !probe.isInFlight(lastAsked: lastAsked)
        guard anchorStands,
            !Self.corroborates(entries, floor: probe.isFloor),
            probe.issues < Self.maxProbeIssues || unanswered
        else {
            Self.retire(&ledger[keyPath: slot])
            return nil
        }
        guard probe.standsIn(for: target),
            superseded
                || probe.issues < Self.maxProbeIssues
                    && (probe.issues == 0 || answered)
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
        if !superseded { probe.issues += 1 }
        probe.slot = frame
        probe.held = false
        ledger[keyPath: slot].pending = probe
        return probe.asked
    }
}
