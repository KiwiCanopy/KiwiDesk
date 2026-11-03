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
