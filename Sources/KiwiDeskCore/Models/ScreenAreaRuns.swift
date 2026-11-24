import Foundation

/// One run of a split screen (#3541): a box cut one or more times
/// along one axis, never stored. Its members are the spans between
/// the cuts, in reading order; a member holds one area, or a nested
/// box whose own run cuts the other axis, since every full-span cut
/// of a box along `axis` belongs to this run.
public struct ScreenAreaRun: Equatable, Sendable {
    public struct Member: Equatable, Sendable {
        /// The span along the run's axis, in screen points.
        public let start: Int
        public let end: Int
        /// Every area inside the member, in reading order.
        public let areas: [Int]

        public var length: Int { end - start }
    }

    public let axis: ScreenAreaCut.Axis
    public let members: [Member]
    /// How many runs enclose this one: 0 for the screen's own.
    public let depth: Int

    /// The member holding area `id`, if any.
    public func member(holding id: Int) -> Int? {
        members.firstIndex { $0.areas.contains(id) }
    }

    /// Each member's length along the axis, in reading order.
    public var lengths: [Int] { members.map(\.length) }
}

/// Derives a split's runs from its rects, through the same
/// guillotine walk as `ScreenAreaCuts`: side by side first, then
/// stacked, in every box.
public enum ScreenAreaRuns {
    /// The runs of `areas` on a `width` × `height` screen, outermost
    /// first; nil where no full-span cut separates them. Empty while
    /// the screen is whole.
    public static func runs(
        of areas: [ScreenArea],
        width: Int,
        height: Int
    ) -> [ScreenAreaRun]? {
        var out: [ScreenAreaRun] = []
        let ok = collect(
            areas,
            box: (0, 0, width, height),
            depth: 0,
            into: &out
        )
        return ok ? out : nil
    }

    private typealias Box = (x: Int, y: Int, w: Int, h: Int)

    private static func collect(
        _ areas: [ScreenArea],
        box: Box,
        depth: Int,
        into out: inout [ScreenAreaRun]
    ) -> Bool {
        guard areas.count > 1 else { return true }
        for axis in [ScreenAreaCut.Axis.sideBySide, .stacked] {
            let side = axis == .sideBySide
            let origin = side ? box.x : box.y
            let far = origin + (side ? box.w : box.h)
            let cuts = positions(areas, axis: axis, from: origin)
            guard !cuts.isEmpty else { continue }
            let edges = [origin] + cuts + [far]
            var members: [ScreenAreaRun.Member] = []
            var inner: [([ScreenArea], Box)] = []
            for (start, end) in zip(edges, edges.dropFirst()) {
                let inside = areas.filter {
                    lo($0, axis) >= start && hi($0, axis) <= end
                }
                members.append(
                    .init(
                        start: start,
                        end: end,
                        areas: ScreenArea.readingOrder(inside).map(\.id)
                    )
                )
                let sub: Box =
                    side
                    ? (start, box.y, end - start, box.h)
                    : (box.x, start, box.w, end - start)
                inner.append((inside, sub))
            }
            out.append(.init(axis: axis, members: members, depth: depth))
            return inner.allSatisfy {
                collect($0.0, box: $0.1, depth: depth + 1, into: &out)
            }
        }
        return false
    }

    /// Every inner position along `axis` no area straddles.
    private static func positions(
        _ areas: [ScreenArea],
        axis: ScreenAreaCut.Axis,
        from origin: Int
    ) -> [Int] {
        Set(areas.map { lo($0, axis) })
            .filter { $0 > origin }
            .filter { at in
                !areas.contains { lo($0, axis) < at && hi($0, axis) > at }
            }
            .sorted()
    }

    static func lo(_ a: ScreenArea, _ axis: ScreenAreaCut.Axis) -> Int {
        axis == .sideBySide ? a.x : a.y
    }

    static func hi(_ a: ScreenArea, _ axis: ScreenAreaCut.Axis) -> Int {
        axis == .sideBySide ? a.x + a.w : a.y + a.h
    }
}
