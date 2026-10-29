import CoreGraphics
import Foundation

/// The corroboration probe (#1439): the deliberate second ask
/// that turns one believed entry into a corroborated bound. The
/// argument is `docs/design-decisions.md` ▸ *The corroborating
/// ask is sent, never awaited*; this file is the contract.
///
/// A confirmation on an axis nothing corroborates yet arms one
/// probe `probeDistance` past the anchor's ask in the refusing
/// direction (`armCorroborationProbe`, from `promote`). The
/// retile loop issues it through `takeCorroborationProbe`, only
/// in place of an ask the anchor already answers and at most
/// `maxProbeIssues` times. Its answer closes it — a confirmation
/// through `promote`, a compliance through `complied`, which
/// also files the retile a performed probe owes — and every ask
/// that has had its probe stays in `AxisProbes.probed` for the
/// ledger's lifetime, which is what refuses a re-arm and the
/// chain off a probe's own confirmation. Pure bookkeeping, like
/// the ledger it rides.
extension SizeBoundLearner {
    struct CorroborationProbe: Equatable {
        /// The believed entry the probe corroborates.
        var anchor: EffectiveSizeBound.Axis
        /// The span to ask.
        var asked: CGFloat
        /// Times the engine has issued it.
        var issues = 0
        /// Whether the pre-ask frame may serve as the probe's
        /// first observation — a baseline producer beside the
        /// retile gate's verdict, held to the four terms
        /// state-and-layout.md ▸ #1439 states. Consumed by the
        /// first issue.
        var baselineTrusted: Bool
        /// Issues a settled read has answered (#2758).
        var answeredIssues = 0
        /// Times the issue out was sent again after an ordinary
        /// ask overwrote it, bounded by `maxProbeResends`.
        var resends = 0
        /// Whether a layout frame was bent to the issue out, which
        /// its answer then owes a placement (#2758).
        var held = false

        var expected: CGFloat { anchor.answered }
        var isFloor: Bool { anchor.isFloor }

        /// Whether a layout span is one the anchor already
        /// answers — its ask or its answer — the one span a probe
        /// may replace.
        func standsIn(for span: CGFloat) -> Bool {
            EffectiveSizeBound.matches(span, anchor.asked)
                || EffectiveSizeBound.matches(span, anchor.answered)
        }

        /// Whether an issue is out with no settled answer yet.
        var isOut: Bool { answeredIssues < issues }

        /// Whether the issue out is still the last ask on its axis.
        func isInFlight(lastAsked: CGFloat?) -> Bool {
            guard isOut, let lastAsked else { return false }
            return EffectiveSizeBound.matches(asked, lastAsked)
        }
    }

    struct AxisProbes: Equatable {
        var pending: CorroborationProbe?
        /// Asks already given their probe — anchors and the
        /// probes' own — one per anchor for the ledger's
        /// lifetime.
        var probed: [CGFloat] = []
        var isEmpty: Bool { pending == nil && probed.isEmpty }
    }

    struct ProbeLedger: Equatable {
        var width = AxisProbes()
        var height = AxisProbes()
        var isEmpty: Bool { width.isEmpty && height.isEmpty }
    }

    /// What the engine issues: the layout's size with each due
    /// axis replaced, and the pre-ask frame where a trusted
    /// baseline lets one settled read complete the pair.
    struct ProbeIssue: Equatable {
        var size: CGSize
        var baseline: CGSize?
        /// Whether an axis took a new issue this pass; false where
        /// the frame only carries an issue already out (#2758).
        var fresh = true
        /// Whether the size is the question already out: the last
        /// ask, carried unchanged (#2758).
        var alreadyOut = false
        /// Whether every carried axis re-asks the anchor's answer —
        /// a residue the layout placed for that size, whose origin
        /// says nothing about where the issue out should sit.
        var residue = false
    }

    /// The first issue, plus the one re-issue the "probing once
    /// more" cycle grants a fresh candidate
    /// (`KiwiCore.observeSizeAnswer`) — so the re-issue waits for
    /// that candidate. A third would be the #1049 loop's shape.
    static let maxProbeIssues = 2

    /// How often an issue out may be sent again after ordinary
    /// asks overwrote it before its answer (#2758) — the bound
    /// that keeps an issue no settled read answers from bending
    /// the layout's frames for good.
    static let maxProbeResends = 3

    /// One point past the bar the pair must clear.
    static var probeDistance: CGFloat {
        EffectiveSizeBound.corroborationDistinctness + 1
    }

    /// The probed list's cap: an anchor and its probe per
    /// remembered entry.
    static var maxProbedPerAxis: Int { maxEntriesPerAxis * 2 }

    static func probeAxis(
        of axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> WritableKeyPath<ProbeLedger, AxisProbes> {
        axis == \.width ? \.width : \.height
    }

    /// Whether `entries` already corroborate a bound in the
    /// direction `floor` names — the accessor every consumer
    /// reads, lend included.
    static func corroborates(
        _ entries: [EffectiveSizeBound.Axis],
        floor: Bool
    ) -> Bool {
        let view = EffectiveSizeBound(width: entries)
        return (floor ? view.minWidth : view.maxWidth) != nil
    }

    /// Arms a probe for a just-believed entry, or nothing. One
    /// at a time per axis: a second anchor confirming while a
    /// probe is pending waits for the layout, as before — the
    /// trade this shape prices. An ask already probed, or an
    /// axis already corroborated in the entry's direction,
    /// stands it down.
    mutating func armCorroborationProbe(
        _ id: WindowID,
        entry: EffectiveSizeBound.Axis,
        entries: [EffectiveSizeBound.Axis],
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>,
        settledRead: Bool
    ) {
        let slot = Self.probeAxis(of: axis)
        var ledger = probes[id] ?? ProbeLedger()
        guard ledger[keyPath: slot].pending == nil,
            !ledger[keyPath: slot].probed.contains(where: {
                EffectiveSizeBound.matches($0, entry.asked)
            }),
            !Self.corroborates(entries, floor: entry.isFloor)
        else { return }
        let asked =
            entry.isFloor
            ? entry.asked - Self.probeDistance
            : entry.asked + Self.probeDistance
        guard asked > 0 else { return }
        ledger[keyPath: slot].pending = CorroborationProbe(
            anchor: entry,
            asked: asked,
            baselineTrusted: settledRead
        )
        probes[id] = ledger
    }

    /// The pending probe's own ask was answered — whatever the
    /// answer, the question is closed. Returns whether a probe
    /// retired, so `complied` can file the retile a PERFORMED
    /// probe owes: the window then holds a size no layout drew.
    @discardableResult
    mutating func retireCorroborationProbe(
        _ id: WindowID,
        answering asked: CGFloat,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> Bool {
        let slot = Self.probeAxis(of: axis)
        guard let probe = probes[id]?[keyPath: slot].pending,
            EffectiveSizeBound.matches(probe.asked, asked)
        else { return false }
        guard var axis = probes[id]?[keyPath: slot] else {
            return false
        }
        Self.retire(&axis)
        probes[id]?[keyPath: slot] = axis
        return true
    }

    /// Closes the pending probe: its anchor's ask and its own
    /// join the probed list, trimmed to the cap.
    static func retire(_ axis: inout AxisProbes) {
        guard let probe = axis.pending else { return }
        axis.pending = nil
        axis.probed.append(probe.anchor.asked)
        axis.probed.append(probe.asked)
        if axis.probed.count > maxProbedPerAxis {
            axis.probed.removeFirst(
                axis.probed.count - maxProbedPerAxis
            )
        }
    }

    /// Whether a pending probe asked `span` on this axis — the
    /// settle probe stays wanted for a compliance there.
    func probePending(
        _ id: WindowID,
        asking span: CGFloat,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> Bool {
        probeExpectation(for: id, asking: span, axis: axis) != nil
    }

    /// An ordinary ask went out: the pre-ask frame is no longer
    /// the settled read that earned a probe its trust.
    mutating func distrustProbeBaselines(_ id: WindowID) {
        probes[id]?.width.pending?.baselineTrusted = false
        probes[id]?.height.pending?.baselineTrusted = false
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
        guard
            let probe = probes[id]?[keyPath: Self.probeAxis(of: axis)]
                .pending,
            EffectiveSizeBound.matches(probe.asked, span)
        else { return nil }
        return probe.expected
    }
}
