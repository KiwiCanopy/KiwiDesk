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
        case minimum
        case thickness
        case outerMargin = "outer_margin"
        case innerMargin = "inner_margin"
        case backgroundStyle = "background_style"
        case liquidGlass = "liquid_glass"
        case backgroundFit = "background_fit"
        case cornerRoundness = "corner_roundness"
        case highlightWidth = "highlight_width"
        case itemGap = "item_gap"
        case fontSize = "font_size"
        case iconSource = "icon_source"
        case dimFactor = "dim_factor"
        case itemColor = "item_color"
        case activeItemColor = "active_item_color"
        case highlightColor = "highlight_color"
        case hoverFillColor = "hover_fill_color"
        case hoverItemColor = "hover_item_color"
        case fillColor = "fill_color"
        case groupBadgeColor = "group_badge_color"
        case groupBadgeTextColor = "group_badge_text_color"
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
        minimum =
            try c.decodeIfPresent(CGFloat.self, forKey: .minimum)
            ?? d.minimum
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
        highlightWidth = Self.clampHighlightWidth(
            try c.decodeIfPresent(
                CGFloat.self,
                forKey: .highlightWidth
            ) ?? d.highlightWidth
        )
        itemGap =
            try c.decodeIfPresent(CGFloat.self, forKey: .itemGap)
            ?? d.itemGap
        fontSize =
            try c.decodeIfPresent(CGFloat.self, forKey: .fontSize)
            ?? d.fontSize
        iconSource =
            try c.decodeIfPresent(
                BarAppIconSource.self,
                forKey: .iconSource
            ) ?? d.iconSource
        dimFactor = AppBarStyle.clampDim(
            try c.decodeIfPresent(CGFloat.self, forKey: .dimFactor)
                ?? d.dimFactor
        )
        try decodeColors(from: c)
    }

    private mutating func decodeColors(
        from c: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let d = Self()
        func color(
            _ key: CodingKeys,
            _ fallback: String
        ) throws -> String {
            try c.decodeIfPresent(String.self, forKey: key) ?? fallback
        }
        itemColor = try color(.itemColor, d.itemColor)
        activeItemColor = try color(.activeItemColor, d.activeItemColor)
        highlightColor = try color(.highlightColor, d.highlightColor)
        hoverFillColor = try color(.hoverFillColor, d.hoverFillColor)
        hoverItemColor = try color(.hoverItemColor, d.hoverItemColor)
        fillColor = try color(.fillColor, d.fillColor)
        groupBadgeColor = try color(.groupBadgeColor, d.groupBadgeColor)
        groupBadgeTextColor = try color(
            .groupBadgeTextColor,
            d.groupBadgeTextColor
        )
    }
}
