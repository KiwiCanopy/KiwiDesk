import CoreGraphics
import Foundation

/// Interactive-resize values for a space with NO authored
/// override of the field (#458): writing the global visibly
/// resized every other space. Session-only — dies with the
/// space, `setMode`, or reload; config layers stay untouched
/// (#290); an in-place restart alone carries it across the
/// process swap (#930). Precedence (authored field > session >
/// global) is structural in `TilingSettings.resolvedBsp/Stack/Scrolling`.
public struct SessionRatios: Sendable, Equatable {
    /// BSP side-by-side split (`resize("x")`).
    public var splitRatioH: Double?
    /// BSP stacked split (`resize("y")`).
    public var splitRatioV: Double?
    /// Stack master/stack split along the split axis.
    public var masterRatio: Double?
    /// Scrolling slot extent along the scroll axis.
    public var slotSize: ScrollSize?
    /// Grid column weights (#763), the whole list.
    public var gridColumnWeights: [Double]?
    /// Grid row weights (#763), the whole list.
    public var gridRowWeights: [Double]?

    public init() {}
}

/// The session snapshot's form (#930). The slot size is written
/// exactly: `ScrollSize`'s own coding rounds a share to two
/// decimals of a percent, which would move a resized slot.
extension SessionRatios: Codable {
    private enum CodingKeys: String, CodingKey {
        case splitRatioH = "split_ratio_h"
        case splitRatioV = "split_ratio_v"
        case masterRatio = "master_ratio"
        case slotPoints = "slot_points"
        case slotFraction = "slot_fraction"
        case slotAuto = "slot_auto"
        case gridColumnWeights = "grid_column_weights"
        case gridRowWeights = "grid_row_weights"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        splitRatioH = try c.decodeIfPresent(
            Double.self,
            forKey: .splitRatioH
        )
        splitRatioV = try c.decodeIfPresent(
            Double.self,
            forKey: .splitRatioV
        )
        masterRatio = try c.decodeIfPresent(
            Double.self,
            forKey: .masterRatio
        )
        if let points = try c.decodeIfPresent(
            Double.self,
            forKey: .slotPoints
        ) {
            slotSize = .points(CGFloat(points))
        } else if let fraction = try c.decodeIfPresent(
            Double.self,
            forKey: .slotFraction
        ) {
            slotSize = .fraction(fraction)
        } else if try c.decodeIfPresent(Bool.self, forKey: .slotAuto)
            == true
        {
            slotSize = .auto
        }
        gridColumnWeights = try c.decodeIfPresent(
            [Double].self,
            forKey: .gridColumnWeights
        )
        gridRowWeights = try c.decodeIfPresent(
            [Double].self,
            forKey: .gridRowWeights
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(splitRatioH, forKey: .splitRatioH)
        try c.encodeIfPresent(splitRatioV, forKey: .splitRatioV)
        try c.encodeIfPresent(masterRatio, forKey: .masterRatio)
        switch slotSize {
        case .points(let points)?:
            try c.encode(Double(points), forKey: .slotPoints)
        case .fraction(let fraction)?:
            try c.encode(fraction, forKey: .slotFraction)
        case .auto?:
            try c.encode(true, forKey: .slotAuto)
        case nil:
            break
        }
        try c.encodeIfPresent(
            gridColumnWeights,
            forKey: .gridColumnWeights
        )
        try c.encodeIfPresent(
            gridRowWeights,
            forKey: .gridRowWeights
        )
    }
}
