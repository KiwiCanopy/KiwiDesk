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
    /// Where any run holds four or more members, or an area sits
    /// three runs deep, every area is numbered in reading order,
    /// from 1.
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

    /// Each area's positional default, by id: one word per run it
    /// sits in, outer run first ("Middle", "Top" for the top half of
    /// a T-junction's middle column), structure the GUI words whole
    /// (#96, #3541). Each run names up to three members Left / Middle /
    /// Right or Top / Middle / Bottom; where a run holds four or
    /// more, or an area sits three runs deep, every area is
    /// numbered in reading order instead, never a mix. Empty while
    /// whole.
    public var positions: [Int: [ScreenAreaPosition]] {
        let all = runs
        guard !all.isEmpty else { return [:] }
        let numbered =
            all.contains { $0.members.count > 3 || $0.depth > 1 }
        if numbered {
            return Dictionary(
                uniqueKeysWithValues: ScreenArea.readingOrder(areas)
                    .enumerated().map { ($1.id, [.numbered($0 + 1)]) }
            )
        }
        var out: [Int: [ScreenAreaPosition]] = [:]
        for run in all {
            for (index, member) in run.members.enumerated() {
                let word = Self.word(index, of: run)
                for id in member.areas {
                    out[id, default: []].append(word)
                }
            }
        }
        return out
    }

    /// Member `index` of `run`'s own position, outer word first: the
    /// path every area in it shares down to the run ("Middle" for a
    /// T-junction's middle column). Nil where the areas are numbered.
    public func position(
        ofMember index: Int,
        in run: ScreenAreaRun
    ) -> [ScreenAreaPosition]? {
        guard run.members.indices.contains(index),
            let first = run.members[index].areas.first,
            let path = positions[first], path.count > run.depth,
            !path.contains(where: {
                if case .numbered = $0 { return true }
                return false
            })
        else { return nil }
        return Array(path.prefix(run.depth + 1))
    }

    private static func word(
        _ index: Int,
        of run: ScreenAreaRun
    ) -> ScreenAreaPosition {
        let side: [ScreenAreaPosition] =
            run.axis == .sideBySide
            ? [.left, .middle, .right] : [.top, .middle, .bottom]
        if run.members.count == 2 { return index == 0 ? side[0] : side[2] }
        return side[index]
    }
}

extension ScreenAreaRun {
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
