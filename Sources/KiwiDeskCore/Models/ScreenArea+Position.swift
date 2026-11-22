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
    /// The axis this split's areas run along, nil while it is
    /// whole. 5.1.0 splits run one way (`mixedAxes`), so the areas'
    /// shared top tells side by side from stacked.
    public var axis: ScreenAreaCut.Axis? {
        guard areas.count > 1 else { return nil }
        let tops = Set(areas.map(\.y))
        return tops.count == 1 ? .sideBySide : .stacked
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
