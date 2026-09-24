import CoreGraphics
import Foundation

/// KiwiShelf CodingKeys and a clamping, default-filling decoder
/// (`KiwiShelfParityTests`). Encode stays synthesized in
/// `KiwiShelf.swift`, so a property absent from `CodingKeys` is
/// silently not encoded — the parity suite is the net.
extension KiwiShelf {
    /// JSON keys are the `kiwishelf.set_*` verbs minus `set_`.
    /// `CaseIterable` is load-bearing — the parity suite reflects
    /// over `allCases`.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case edge
        case alignment
        case order
        case share
        case thickness
        case outerMargin = "outer_margin"
        case innerMargin = "inner_margin"
        case backgroundStyle = "background_style"
        case liquidGlass = "liquid_glass"
        case backgroundFit = "background_fit"
        case cornerRoundness = "corner_roundness"
        case itemGap = "item_gap"
        case fontSize = "font_size"
    }

    /// Decodes a shelf, a missing key taking its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self()
        edge =
            try c.decodeIfPresent(AppBarEdge.self, forKey: .edge)
            ?? d.edge
        alignment =
            try c.decodeIfPresent(Alignment.self, forKey: .alignment)
            ?? d.alignment
        order =
            try c.decodeIfPresent(Order.self, forKey: .order)
            ?? d.order
        share =
            try c.decodeIfPresent(CGFloat.self, forKey: .share)
            ?? d.share
        thickness = max(
            Self.minThickness,
            try c.decodeIfPresent(CGFloat.self, forKey: .thickness)
                ?? d.thickness
        )
        outerMargin = max(
            Self.minMargin,
            try c.decodeIfPresent(CGFloat.self, forKey: .outerMargin)
                ?? d.outerMargin
        )
        innerMargin = max(
            Self.minMargin,
            try c.decodeIfPresent(CGFloat.self, forKey: .innerMargin)
                ?? d.innerMargin
        )
        backgroundStyle =
            try c.decodeIfPresent(
                BackgroundStyle.self,
                forKey: .backgroundStyle
            ) ?? d.backgroundStyle
        liquidGlass =
            try c.decodeIfPresent(Bool.self, forKey: .liquidGlass)
            ?? d.liquidGlass
        backgroundFit =
            try c.decodeIfPresent(
                BackgroundFit.self,
                forKey: .backgroundFit
            ) ?? d.backgroundFit
        cornerRoundness =
            try c.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRoundness
            ) ?? d.cornerRoundness
        itemGap =
            try c.decodeIfPresent(CGFloat.self, forKey: .itemGap)
            ?? d.itemGap
        fontSize =
            try c.decodeIfPresent(CGFloat.self, forKey: .fontSize)
            ?? d.fontSize
    }
}
