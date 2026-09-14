import CoreGraphics
import Foundation

/// The corroboration probe (#1439): the deliberate second ask
/// that turns one believed entry into a corroborated bound.
///
/// An entry confirms about a second after a window arrives, but
/// every consumer of a CORROBORATED bound — `minWidth` and its
/// three siblings: the resize refusal pill, Scrolling's re-pack
/// past the entry's own ask, Track's automatic count and floor
/// re-share (#1355) — waits for a second ask at least
/// `corroborationDistinctness` away from the first, and nothing
/// sends one until the layout happens to change (owner sitting
/// 2026-09-14: 8–18 s, the table is on the issue). So the
/// learner asks it itself. A confirmation on an axis no
/// corroborated bound answers ARMS one probe, `probeDistance`
/// past the anchor's ask in the refusing direction (a floor:
/// smaller; a ceiling: larger), and the retile loop issues it
/// in place of the layout's own ask — only where that ask is one
/// the anchor already answers, so a probe never displaces an ask
/// the ladder has not heard. A true bound answers with the
/// anchor's span and the pair corroborates through the ordinary
/// ladder; a grid-snapping app answers a few points off and
/// nothing corroborates, exactly as #1055 intends.
///
/// Bounded three ways, each at its site: one probe per axis per
/// anchor (`arm`), issued at most `maxProbeIssues` times
/// (`take`), and a probe's own confirmation arms nothing
/// (`retire`, ahead of `arm` in `promote`), so the chain ends at
/// the second ask. Pure bookkeeping, like the ledger it rides.
extension SizeBoundLearner {
    struct CorroborationProbe: Equatable {
        /// The believed entry the probe corroborates.
        var anchor: EffectiveSizeBound.Axis
        /// The span to ask.
        var asked: CGFloat
        /// Times the engine has issued it.
        var issues = 0
        /// Answered, out of issues, or orphaned. Kept until
        /// `forget` rather than dropped with its anchor: a grid
        /// app can answer the probe INSIDE the match tolerance,
        /// which the compliance sweep reads as the constraint
        /// lifting and sweeps the anchor — the layout then
        /// re-confirms the same entry, and a record that left
        /// with the anchor would arm the same probe again, a
        /// dance every cycle. One probe per anchor ask, per
        /// ledger lifetime.
        var retired = false
        /// Whether the window's pre-ask frame may serve as the
        /// probe's first observation: the anchor's confirming
        /// read was SETTLED and no ask has gone out since, so
        /// that read is more recent than the set the applier's
        /// echo grace still protects — a real prior observation,
        /// not a frame that may never have moved (#1083's
        /// distinction, kept). Consumed by the first issue.
        var baselineTrusted: Bool

        var expected: CGFloat { anchor.answered }
        var isFloor: Bool { anchor.answered > anchor.asked }
    }

    struct ProbeLedger: Equatable {
        var width: CorroborationProbe?
        var height: CorroborationProbe?
        var isEmpty: Bool { width == nil && height == nil }
    }

    /// What the engine issues: the layout's size with each due
    /// axis replaced, and the pre-ask frame where a trusted
    /// baseline lets one settled read complete the pair.
    struct ProbeIssue: Equatable {
        var size: CGSize
        var baseline: CGSize?
    }

    /// Issues per probe: the first, plus the one re-issue the
    /// "probing once more" cycle already grants a fresh
    /// candidate (`KiwiCore.observeSizeAnswer`) — without a
    /// trusted baseline the first read only seeds the probe's
    /// candidate, and the re-issue is what a settled read then
    /// confirms. So the re-issue waits for that candidate: an
    /// unrelated retile before the first answer re-asks nothing.
    /// A third issue would be the #1049 loop's shape.
    static let maxProbeIssues = 2

    /// One point past the bar the pair must clear.
    static var probeDistance: CGFloat {
        EffectiveSizeBound.corroborationDistinctness + 1
    }

    static func probeAxis(
        of axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> WritableKeyPath<ProbeLedger, CorroborationProbe?> {
        axis == \.width ? \.width : \.height
    }

    /// Whether `entries` already corroborate a bound in the
    /// direction `floor` names — the same accessor every
    /// consumer reads, lend included.
    static func corroborates(
        _ entries: [EffectiveSizeBound.Axis],
        floor: Bool
    ) -> Bool {
        let view = EffectiveSizeBound(width: entries)
        return (floor ? view.minWidth : view.maxWidth) != nil
    }

    /// Arms a probe for a just-believed entry, or nothing: a
    /// probe still pending, one retired for this anchor's ask
    /// or for this very ask (the probe's own confirmation, which
    /// must not chain), or an axis already corroborated in the
    /// entry's direction all stand it down. A retired record for
    /// a DIFFERENT ask gives way — each anchor gets its one.
    mutating func armCorroborationProbe(
        _ id: WindowID,
        entry: EffectiveSizeBound.Axis,
        entries: [EffectiveSizeBound.Axis],
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>,
        settledRead: Bool
    ) {
        let slot = Self.probeAxis(of: axis)
        var ledger = probes[id] ?? ProbeLedger()
        if let existing = ledger[keyPath: slot] {
            guard existing.retired,
                !EffectiveSizeBound.matches(
                    existing.anchor.asked,
                    entry.asked
                ),
                !EffectiveSizeBound.matches(
                    existing.asked,
                    entry.asked
                )
            else { return }
        }
        let isFloor = entry.answered > entry.asked
        guard !Self.corroborates(entries, floor: isFloor)
        else { return }
        let asked =
            isFloor
            ? entry.asked - Self.probeDistance
            : entry.asked + Self.probeDistance
        guard asked > 0 else { return }
        ledger[keyPath: slot] = CorroborationProbe(
            anchor: entry,
            asked: asked,
            baselineTrusted: settledRead
        )
        probes[id] = ledger
    }

    /// The probe's own ask was answered — whatever the answer,
    /// the question is closed.
    mutating func retireCorroborationProbe(
        _ id: WindowID,
        answering asked: CGFloat,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) {
        let slot = Self.probeAxis(of: axis)
        guard var probe = probes[id]?[keyPath: slot],
            EffectiveSizeBound.matches(probe.asked, asked)
        else { return }
        probe.retired = true
        probes[id]?[keyPath: slot] = probe
    }

    /// The engine's door: what to issue in place of the layout's
    /// `target` on this pass, nil when nothing is due. Due only
    /// where the layout's span is one the anchor already answers
    /// — its ask or its answer — since the retile would skip that
    /// as explained and the probe may not displace any other;
    /// retired when the anchor is gone (a compliance lifted it),
    /// when the axis corroborated meanwhile, and once
    /// `maxProbeIssues` are out.
    mutating func takeCorroborationProbe(
        _ id: WindowID,
        current: CGSize,
        target: CGSize
    ) -> ProbeIssue? {
        guard var ledger = probes[id] else { return nil }
        var size = target
        var trusted = false
        if let asked = takeProbeAxis(
            &ledger,
            slot: \.width,
            entries: bounds[id]?.width ?? [],
            candidates: candidates[id]?.width ?? [],
            current: current.width,
            target: target.width,
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
            trusted: &trusted
        ) {
            size.height = asked
        }
        probes[id] = ledger
        guard size != target else { return nil }
        return ProbeIssue(
            size: size,
            baseline: trusted ? current : nil
        )
    }

    private func takeProbeAxis(
        _ ledger: inout ProbeLedger,
        slot: WritableKeyPath<ProbeLedger, CorroborationProbe?>,
        entries: [EffectiveSizeBound.Axis],
        candidates: [EffectiveSizeBound.Axis],
        current: CGFloat,
        target: CGFloat,
        trusted: inout Bool
    ) -> CGFloat? {
        guard var probe = ledger[keyPath: slot], !probe.retired
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
            probe.issues < Self.maxProbeIssues
        else {
            probe.retired = true
            ledger[keyPath: slot] = probe
            return nil
        }
        guard
            EffectiveSizeBound.matches(target, probe.anchor.asked)
                || EffectiveSizeBound.matches(
                    target,
                    probe.anchor.answered
                ),
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
        ledger[keyPath: slot] = probe
        return probe.asked
    }

    /// An ordinary ask went out: the pre-ask frame is no longer
    /// the settled read that earned a probe its trust.
    mutating func distrustProbeBaselines(_ id: WindowID) {
        probes[id]?.width?.baselineTrusted = false
        probes[id]?.height?.baselineTrusted = false
    }

    /// The answer a probe in flight toward `span` expects — the
    /// overlay pin's third fallback, so the ring renders the
    /// probe at the anchor's answer as it does the second probe
    /// at the candidate's. Rendering only; geometry never reads
    /// a probe.
    func probeExpectation(
        for id: WindowID,
        asking span: CGFloat,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> CGFloat? {
        guard let probe = probes[id]?[keyPath: Self.probeAxis(of: axis)],
            EffectiveSizeBound.matches(probe.asked, span)
        else { return nil }
        return probe.expected
    }
}
