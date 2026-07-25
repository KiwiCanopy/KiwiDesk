import CoreGraphics
import Foundation

/// `SpaceBarStyle`'s wire form, split out of the type's own file
/// at the 350-line ceiling (AGENTS.md §2.1): the struct keeps the
/// fields and their rationale, the keys and the decode live here.
///
/// It borrows the `+Coding` file name from
/// `TilingSettings+Coding.swift` but **not** its shape, and the
/// difference is load-bearing: that type declares its conformance
/// in the `+Coding` file and hand-writes `encode(to:)` in a third
/// file. Here the conformance stays in `SpaceBarStyle.swift`,
/// because Swift only synthesizes `encode(to:)` where the
/// conformance sits — so encode remains generated and a new
/// stored property cannot be silently dropped from the wire.
/// Moving the conformance into this file is a compile error, not
/// a subtle regression; the compiler enforces the arrangement.
///
/// Sparse by design — a decode falls back to `defaults` per
/// field, so a profile written before a field existed still
/// loads. That per-field fallback is a hand-mirrored list, which
/// is why `SpaceBarParityTests` reflects over
/// `CodingKeys.allCases` (`.claude/rules/parity-tests.md`).

extension SpaceBarStyle {
    /// JSON keys are the Lua setters (`space_bar.set_*`) minus
    /// the `set_` verb. `CaseIterable` is load-bearing: the
    /// parity test (`SpaceBarParityTests`) reflects over
    /// `allCases` to prove every field has a key.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case edge
        case alignment
        case thickness
        case itemSize = "item_size"
        case itemGap = "item_gap"
        case fontSize = "font_size"
        case glyphCap = "glyph_cap"
        case iconSource = "icon_source"
        case backgroundStyle = "background_style"
        case liquidGlass = "liquid_glass"
        case backgroundFit = "background_fit"
        case activeIndicator = "active_indicator"
        case cornerRoundness = "corner_roundness"
        case dimFactor = "dim_factor"
        case activeDimFactor = "active_dim_factor"
        case showFrontApp = "show_front_app"
        case hideEmpty = "hide_empty"
        case stickyBadge = "sticky_badge"
        case springDelay = "spring_delay"
        case itemColor = "item_color"
        case activeItemColor = "active_item_color"
        case focusedItemColor = "focused_item_color"
        case hoverFillColor = "hover_fill_color"
        case hoverItemColor = "hover_item_color"
        case fillColor = "fill_color"
        case highlightColor = "highlight_color"
        case groupBadgeColor = "group_badge_color"
        case groupBadgeTextColor = "group_badge_text_color"
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? defaults.enabled
        edge =
            try container.decodeIfPresent(
                AppBarEdge.self,
                forKey: .edge
            ) ?? defaults.edge
        alignment =
            try container.decodeIfPresent(
                Alignment.self,
                forKey: .alignment
            ) ?? defaults.alignment
        thickness = max(
            AppBarStyle.minThickness,
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .thickness
            ) ?? defaults.thickness
        )
        itemSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .itemSize
            ) ?? defaults.itemSize
        itemGap =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .itemGap
            ) ?? defaults.itemGap
        fontSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .fontSize
            ) ?? defaults.fontSize
        glyphCap =
            try container.decodeIfPresent(
                Int.self,
                forKey: .glyphCap
            ) ?? defaults.glyphCap
        iconSource =
            try container.decodeIfPresent(
                BarAppIconSource.self,
                forKey: .iconSource
            ) ?? defaults.iconSource
        backgroundStyle =
            try container.decodeIfPresent(
                BackgroundStyle.self,
                forKey: .backgroundStyle
            ) ?? defaults.backgroundStyle
        liquidGlass =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .liquidGlass
            ) ?? defaults.liquidGlass
        backgroundFit =
            try container.decodeIfPresent(
                BackgroundFit.self,
                forKey: .backgroundFit
            ) ?? defaults.backgroundFit
        activeIndicator =
            try container.decodeIfPresent(
                ActiveIndicator.self,
                forKey: .activeIndicator
            ) ?? defaults.activeIndicator
        cornerRoundness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRoundness
            ) ?? defaults.cornerRoundness
        dimFactor = AppBarStyle.clampDim(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .dimFactor
            ) ?? defaults.dimFactor
        )
        activeDimFactor = AppBarStyle.clampDim(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .activeDimFactor
            ) ?? defaults.activeDimFactor
        )
        showFrontApp =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .showFrontApp
            ) ?? defaults.showFrontApp
        hideEmpty =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .hideEmpty
            ) ?? defaults.hideEmpty
        stickyBadge =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .stickyBadge
            ) ?? defaults.stickyBadge
        springDelay =
            try container.decodeIfPresent(
                Int.self,
                forKey: .springDelay
            ) ?? defaults.springDelay
        try decodeColors(from: container)
    }

    private mutating func decodeColors(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let defaults = Self()
        itemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .itemColor
            ) ?? defaults.itemColor
        activeItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .activeItemColor
            ) ?? defaults.activeItemColor
        focusedItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .focusedItemColor
            ) ?? defaults.focusedItemColor
        hoverFillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .hoverFillColor
            ) ?? defaults.hoverFillColor
        hoverItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .hoverItemColor
            ) ?? defaults.hoverItemColor
        fillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .fillColor
            ) ?? defaults.fillColor
        highlightColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .highlightColor
            ) ?? defaults.highlightColor
        groupBadgeColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .groupBadgeColor
            ) ?? defaults.groupBadgeColor
        groupBadgeTextColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .groupBadgeTextColor
            ) ?? defaults.groupBadgeTextColor
    }
}
