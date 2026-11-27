import Foundation

/// The fewest points an area may have along each cut, from the
/// layouts' minimum window size (`TilingSettings.areaFloors`), so the
/// verdict below never reads settings (#3647 ▸ lane 3).
public struct AreaFloors: Equatable, Sendable {
    public var sideBySide: Int
    public var stacked: Int

    public init(sideBySide: Int, stacked: Int) {
        self.sideBySide = sideBySide
        self.stacked = stacked
    }

    /// No floor past `ScreenArea.minimumSide`: what is stored, as a
    /// readout shows it.
    public static let unfloored = AreaFloors(
        sideBySide: ScreenArea.minimumSide,
        stacked: ScreenArea.minimumSide
    )
}

extension ScreenSplit {
    /// How a screen draws a stored split (#3647 ▸ no-fit ruling): split,
    /// whole, or whole because an area would fall under the floor
    /// along the axis named.
    public enum Verdict: Equatable, Sendable {
        case split(ScreenSplit)
        case whole
        case tooSmall(ScreenAreaCut.Axis)

        /// The split drawn, nil where the screen draws whole.
        public var split: ScreenSplit? {
            if case .split(let split) = self { return split }
            return nil
        }
    }

    /// The one verdict the placements, the Settings picture, the
    /// greyed numbers and the fit search take. An area is judged only
    /// along an axis it is cut along, with one per-mille step of that
    /// axis given back for the share's rounding; the first area in
    /// reading order that fails names the axis, width before height.
    public static func verdict(
        _ stored: ScreenSplit?,
        width: Int,
        height: Int,
        floors: AreaFloors
    ) -> Verdict {
        guard
            let split = effective(stored, width: width, height: height)
        else { return .whole }
        let stepW = (width + ScreenShares.whole - 1) / ScreenShares.whole
        let stepH = (height + ScreenShares.whole - 1) / ScreenShares.whole
        for area in ScreenArea.readingOrder(split.areas) {
            if area.w < width, area.w < floors.sideBySide - stepW {
                return .tooSmall(.sideBySide)
            }
            if area.h < height, area.h < floors.stacked - stepH {
                return .tooSmall(.stacked)
            }
        }
        return .split(split)
    }
}

extension TilingSettings {
    /// The area floors along each cut, `areaFloor(along:)`'s.
    public var areaFloors: AreaFloors {
        AreaFloors(
            sideBySide: areaFloor(along: .sideBySide),
            stacked: areaFloor(along: .stacked)
        )
    }
}
