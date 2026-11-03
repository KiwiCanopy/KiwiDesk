import CoreGraphics

/// Where a push's length plans (#2709, `Space.runSizes`): the one
/// gate `RunZone.placement` asks, so the pass that draws a run and
/// the store it persists never disagree.
extension RunZone {
    /// The lengths pushes gave members, by member index, honoured
    /// only for a length given in this zone (`RunSize.zone`), while
    /// its run keeps stored ends and would still hide a window with
    /// them: a window moved to another zone, or a run that would
    /// show everything at its floors, plans at its floor and share.
    func honouredSizes(
        bare: [CGFloat],
        gap: CGFloat,
        in context: LayoutContext
    ) -> [Int: CGFloat] {
        guard let first = members.first,
            members.contains(where: {
                context.runHeads.contains($0) || context.runTails.contains($0)
            })
        else { return [:] }
        var sizes: [Int: CGFloat] = [:]
        for (index, member) in members.enumerated() {
            guard let size = context.runSizes[member], size.zone == first
            else { continue }
            sizes[index] = max(min(size.share * span, span), bare[index])
        }
        let planned = members.indices.map { sizes[$0] ?? bare[$0] }
        return ZoneRun.fits(planned, gap: gap, span: span) ? [:] : sizes
    }
}
