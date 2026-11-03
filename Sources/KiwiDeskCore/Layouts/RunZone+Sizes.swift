import CoreGraphics

/// Where a push's length plans (#2709, `Space.runSizes`): the one
/// gate `RunZone.placement` asks and the persist step keeps by
/// (`RunCover.Run.sized`), so the pass that draws a run and the
/// store it persists never disagree.
extension RunZone {
    /// The length a stored `share` plans at: that share of the span,
    /// never past the span or below the window's `floor`. The render
    /// and a press both take it, so a press plans what is drawn.
    func plannedLength(share: CGFloat, floor: CGFloat) -> CGFloat {
        max(min(share * span, span), floor)
    }

    /// The share `length` is stored as.
    func share(of length: CGFloat) -> CGFloat {
        span > 0 ? length / span : 0
    }

    /// The lengths pushes gave members, by member index, honoured
    /// only for a length given in a zone of this role (`RunSize.zone`),
    /// while its run keeps stored ends and would still hide a window
    /// with them: a window moved to a zone of another role, or a run
    /// that would show everything at its floors, plans at its floor
    /// and share.
    func honouredSizes(
        bare: [CGFloat],
        gap: CGFloat,
        in context: LayoutContext
    ) -> [Int: CGFloat] {
        guard
            members.contains(where: {
                context.runHeads.contains($0) || context.runTails.contains($0)
            })
        else { return [:] }
        var sizes: [Int: CGFloat] = [:]
        for (index, member) in members.enumerated() {
            guard let size = context.runSizes[member], size.zone == ordinal
            else { continue }
            sizes[index] = plannedLength(share: size.share, floor: bare[index])
        }
        let planned = members.indices.map { sizes[$0] ?? bare[$0] }
        return ZoneRun.fits(planned, gap: gap, span: span) ? [:] : sizes
    }

    /// `id`'s weight apart from any length: its stored share, or 1.
    func plainWeight(
        of id: WindowID,
        in context: LayoutContext
    ) -> Double {
        max(context.stackWeights[id] ?? 1, StackLayout.weightFloor)
    }

    /// The weight that draws `id` at `length` once this zone's run
    /// ends and lengths are gone, every member showing: tried against
    /// the render itself, whose whole split and floor-and-share split
    /// each hold only where the floors allow.
    func weight(
        drawing id: WindowID,
        at length: CGFloat,
        floor: CGFloat,
        in context: LayoutContext
    ) -> Double {
        var plain = context
        for member in members { plain.runSizes[member] = nil }
        (plain.runHeads, plain.runTails) = ends(
            showing: members.indices,
            heads: context.runHeads,
            tails: context.runTails
        )
        let others = members.filter { $0 != id }
        let total = others.reduce(0.0) {
            $0 + plainWeight(of: $1, in: context)
        }
        let (_, bare, gap) = floorsAndGap(in: context)
        let available = span - gap * CGFloat(max(members.count - 1, 0))
        func ratio(_ part: CGFloat, of whole: CGFloat) -> Double? {
            whole > part && part > 0 ? Double(part / (whole - part)) : nil
        }
        let candidates = [
            ratio(length, of: available),
            ratio(length - floor, of: available - bare.reduce(0, +)),
        ].compactMap { $0.map { $0 * total } }
        func drawn(_ weight: Double) -> CGFloat {
            var trial = plain
            trial.stackWeights[id] = weight
            let frame = frames(in: trial)[id]
            return (vertical ? frame?.height : frame?.width) ?? 0
        }
        let range = StackLayout.weightRange
        return
            candidates
            .map { min(max($0, range.lowerBound), range.upperBound) }
            .min { abs(drawn($0) - length) < abs(drawn($1) - length) }
            ?? range.lowerBound
    }

    /// The members whose stored length this zone plans — what the
    /// persist step keeps.
    func sizedMembers(in context: LayoutContext) -> Set<WindowID> {
        let (_, bare, gap) = floorsAndGap(in: context)
        return Set(
            honouredSizes(bare: bare, gap: gap, in: context).keys.map {
                members[$0]
            }
        )
    }
}
