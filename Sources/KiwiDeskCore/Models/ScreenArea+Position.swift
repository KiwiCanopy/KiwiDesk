import Foundation

/// One word of an area's positional default name (#3517 ruling
/// 15, #3541), as structure: the GUI words it in the user's
/// language.
public enum ScreenAreaPosition: Hashable, Sendable {
    case left
    case middle
    case right
    case top
    case bottom
    /// Where any run holds four or more members, every area is
    /// numbered in reading order, from 1.
    case numbered(Int)
}

extension ScreenSplit {
    /// The split's runs (`ScreenAreaRuns`), outermost first; empty
    /// while whole or where no full-span cut separates the areas.
    public var runs: [ScreenAreaRun] {
        guard areas.count > 1 else { return [] }
        return ScreenAreaRuns.runs(
            of: areas,
            width: extent.width,
            height: extent.height
        ) ?? []
    }

    /// The axis this split's areas run along while every cut runs
    /// one way; nil while whole or nested (#3541).
    public var axis: ScreenAreaCut.Axis? {
        let all = runs
        guard let first = all.first?.axis,
            all.allSatisfy({ $0.axis == first })
        else { return nil }
        return first
    }

    /// The run area `id` is a direct member of: the row or column
    /// the selection sits in (#3541). Nil while whole.
    public func run(holding id: Int) -> ScreenAreaRun? {
        runs.last { run in
            run.members.contains { $0.areas == [id] }
        }
    }

    /// Each area's positional default, by id, outer word first:
    /// "Middle Top" in a T-junction, "Top Left" on a 2×2 (Left and
    /// Right always come last, after the #3528 notes). Each run
    /// names up to three members Left / Middle / Right or Top /
    /// Middle / Bottom; where a run holds four or more, every area
    /// is numbered in reading order instead, never a mix. Empty
    /// while whole.
    public var positions: [Int: [ScreenAreaPosition]] {
        let all = runs
        guard !all.isEmpty else { return [:] }
        let ordered = ScreenArea.readingOrder(areas).map(\.id)
        if all.contains(where: { $0.members.count > 3 }) {
            return Dictionary(
                uniqueKeysWithValues: ordered.enumerated().map {
                    ($1, [.numbered($0 + 1)])
                }
            )
        }
        var out: [Int: [ScreenAreaPosition]] = [:]
        for run in all {
            for (index, member) in run.members.enumerated() {
                let word = Self.word(
                    index,
                    of: run.members.count,
                    axis: run.axis
                )
                for id in member.areas {
                    out[id, default: []].append(word)
                }
            }
        }
        return out.mapValues(Self.reading)
    }

    private static func word(
        _ index: Int,
        of count: Int,
        axis: ScreenAreaCut.Axis
    ) -> ScreenAreaPosition {
        let side: [ScreenAreaPosition] =
            axis == .sideBySide
            ? [.left, .middle, .right] : [.top, .middle, .bottom]
        if count == 2 { return index == 0 ? side[0] : side[2] }
        return side[index]
    }

    /// A path in reading order: Left / Right last, and a "Middle"
    /// of a middle said once ("Middle", not "Middle Middle").
    private static func reading(
        _ path: [ScreenAreaPosition]
    ) -> [ScreenAreaPosition] {
        let sides: Set<ScreenAreaPosition> = [.left, .right]
        let ordered =
            path.filter { !sides.contains($0) }
            + path.filter { sides.contains($0) }
        var out: [ScreenAreaPosition] = []
        for word in ordered
        where !(word == .middle && out.last == .middle) {
            out.append(word)
        }
        return out
    }
}

extension ScreenAreaRun {
    /// Whether every member is as long as an even split makes it:
    /// lengths a point apart at most, the longer ones leading.
    public var isEven: Bool {
        let all = lengths
        guard let first = all.first, let last = all.last else {
            return true
        }
        return first - last <= 1 && all == all.sorted(by: >)
    }

    /// Each member's share of the run in whole percent, in reading
    /// order, adding up to 100 (largest remainder): for display
    /// only, since a split stores points.
    public var percents: [Int] {
        let all = lengths
        let total = all.reduce(0, +)
        guard total > 0 else { return all.map { _ in 0 } }
        var shares = all.map { $0 * 100 / total }
        let order = all.indices.sorted {
            (all[$0] * 100 % total, -$0) > (all[$1] * 100 % total, -$1)
        }
        for index in order.prefix(100 - shares.reduce(0, +)) {
            shares[index] += 1
        }
        return shares
    }

    /// `percent` of the run along its axis, in points.
    public func points(percent: Double) -> Int {
        Int((percent * Double(lengths.reduce(0, +)) / 100).rounded())
    }
}
