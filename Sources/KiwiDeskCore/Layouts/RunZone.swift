import CoreGraphics

/// One region a Stack zone or a Track track lays its members
/// along (#2235): the shared placement both layouts take, so a
/// zone that overflows scrolls the same way in either.
public struct RunZone: Sendable, Equatable {
    /// Members in drawn order.
    public let members: [WindowID]
    public let region: CGRect
    /// Members stack top to bottom when true, else left to right.
    public let vertical: Bool

    public init(members: [WindowID], region: CGRect, vertical: Bool) {
        self.members = members
        self.region = region
        self.vertical = vertical
    }

    /// The run this zone draws, or nil where it draws none: every
    /// member fits at its weighted share, or the zone cannot hold
    /// even one window at the minimum size and piles whole.
    public func run(in context: LayoutContext) -> ZoneRun? {
        guard !members.isEmpty, !fitsWhole(in: context),
            !piles(in: context)
        else { return nil }
        return ZoneRun.resolve(
            floors: floors(in: context),
            span: span,
            gap: gap(in: context),
            head: ZoneRun.head(of: members, in: context.runHeads),
            focus: context.focused.flatMap { members.firstIndex(of: $0) }
        )
    }

    /// Frames for every member.
    public func frames(in context: LayoutContext) -> [WindowID: CGRect] {
        guard !members.isEmpty else { return [:] }
        if piles(in: context) {
            return OverlapStack.frames(
                for: members,
                in: region,
                minSize: context.minWindowSize
            )
        }
        let rects: [CGRect]
        if let run = run(in: context) {
            rects = run.frames(
                floors: floors(in: context),
                weights: weights(in: context),
                in: region,
                vertical: vertical,
                gap: gap(in: context)
            )
        } else {
            rects = weightedRects(in: context)
        }
        return Dictionary(uniqueKeysWithValues: zip(members, rects))
    }

    private var span: CGFloat { vertical ? region.height : region.width }

    private func gap(in context: LayoutContext) -> CGFloat {
        vertical ? context.gaps.inner.vertical : context.gaps.inner.horizontal
    }

    private func weights(in context: LayoutContext) -> [Double] {
        members.map {
            max(context.stackWeights[$0] ?? 1, StackLayout.weightFloor)
        }
    }

    private func floors(in context: LayoutContext) -> [CGFloat] {
        members.map { context.runFloor(of: $0, horizontal: !vertical) }
    }

    /// The emergency whole-zone pile (#44): not even one window
    /// fits at the minimum size.
    private func piles(in context: LayoutContext) -> Bool {
        span <= 0
            || span < context.minWindowSize.along(horizontal: !vertical)
    }

    /// Every member fits: the weighted shares keep the minimum
    /// size (#67) and the floors fit side by side.
    private func fitsWhole(in context: LayoutContext) -> Bool {
        let gaps = gap(in: context) * CGFloat(members.count - 1)
        let available = span - gaps
        let weights = weights(in: context)
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            span: Double(available),
            minSize: Double(
                context.minWindowSize.along(horizontal: !vertical)
            )
        )
        let floorTotal = floors(in: context).reduce(0, +)
        return available > 0 && weights.reduce(0, +) <= limit
            && floorTotal <= available
    }

    private func weightedRects(in context: LayoutContext) -> [CGRect] {
        let gap = gap(in: context)
        let available = span - gap * CGFloat(members.count - 1)
        let weights = weights(in: context)
        let total = weights.reduce(0, +)
        var position = vertical ? region.minY : region.minX
        return weights.map { weight in
            let extent = available * CGFloat(weight / total)
            defer { position += extent + gap }
            return vertical
                ? CGRect(
                    x: region.minX,
                    y: position,
                    width: region.width,
                    height: extent
                )
                : CGRect(
                    x: position,
                    y: region.minY,
                    width: extent,
                    height: region.height
                )
        }
    }
}
