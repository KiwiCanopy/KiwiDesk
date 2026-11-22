import Foundation

/// An area's positional default name (#3517 ruling 15), as
/// structure: the GUI words it in the user's language.
public enum ScreenAreaPosition: Hashable, Sendable {
    case left
    case middle
    case right
    case top
    case bottom
    /// From four areas, every area is numbered in reading order,
    /// from 1.
    case numbered(Int)
}

extension ScreenSplit {
    /// The axis this split's areas run along, read off its cuts
    /// (ruling 20); nil while whole or where the cuts run both ways.
    /// The lengths, names and percents below read the one run a
    /// 5.1.0 split has (`mixedAxes`); nested splits (#3541) owe them
    /// per run.
    public var axis: ScreenAreaCut.Axis? {
        guard areas.count > 1,
            let cuts = ScreenAreaCuts.cuts(
                of: areas,
                width: extent.width,
                height: extent.height
            ),
            let first = cuts.first?.axis,
            cuts.allSatisfy({ $0.axis == first })
        else { return nil }
        return first
    }

    /// Each area's positional default, by id: Left / Right,
    /// Left / Middle / Right (Top / … stacked) up to three areas,
    /// then all numbered in reading order. Empty while whole.
    public var positions: [Int: ScreenAreaPosition] {
        guard let axis else { return [:] }
        let ordered = ScreenArea.readingOrder(areas)
        let names: [ScreenAreaPosition]
        switch (ordered.count, axis) {
        case (2, .sideBySide): names = [.left, .right]
        case (3, .sideBySide): names = [.left, .middle, .right]
        case (2, .stacked): names = [.top, .bottom]
        case (3, .stacked): names = [.top, .middle, .bottom]
        default: names = ordered.indices.map { .numbered($0 + 1) }
        }
        return Dictionary(
            uniqueKeysWithValues: zip(ordered.map(\.id), names)
        )
    }

    /// Each area's length along the split's axis, in reading order.
    public var lengths: [Int] {
        guard let axis else { return [] }
        return ScreenArea.readingOrder(areas).map {
            axis == .sideBySide ? $0.w : $0.h
        }
    }

    /// Whether every area is as long as an even split makes it:
    /// lengths a point apart at most, the longer ones leading.
    public var isEven: Bool {
        let all = lengths
        guard let first = all.first, let last = all.last else {
            return true
        }
        return first - last <= 1 && all == all.sorted(by: >)
    }
}
