import CoreGraphics
import Foundation

/// `AppBarStyle`'s wire form, split out of the type's own file at
/// the 350-line ceiling (AGENTS.md §2.1) — the same arrangement
/// `SpaceBarStyle+Coding.swift` already carries, and for the same
/// reason.
///
/// The `Codable` conformance deliberately stays in
/// `AppBarStyle.swift`: Swift only synthesizes `encode(to:)`
/// where the conformance sits, so keeping it there leaves encode
/// generated rather than hand-written — one fewer field list to
/// forget. It is NOT a guarantee that a new stored property
/// reaches the wire: a property absent from `CodingKeys` below
/// is silently not encoded, with no error. `AppBarParityTests`
/// (reflection over `CodingKeys.allCases` against the struct's
/// fields) is the actual net for that.
///
/// Sparse by design — every field falls back to `defaults`, so a
/// profile written before a field existed still loads.
extension AppBarStyle {
    /// JSON keys are the Lua setters (`app_bar.set_*`) minus the
    /// `set_` verb — the `app_bar` nesting carries the namespace.
    /// `CaseIterable` is load-bearing: the parity test
    /// (`AppBarParityTests`) reflects over `allCases` to prove
    /// every field has a key — do not drop it as "unused".
    enum CodingKeys: String, CodingKey, CaseIterable {
        case edge
        case alignment
        case thickness
        case backgroundStyle = "background_style"
        case liquidGlass = "liquid_glass"
        case backgroundFit = "background_fit"
        case activeIndicator = "active_indicator"
        case itemSize = "item_size"
        case itemGap = "item_gap"
        case content
        case titleCap = "title_cap"
        case iconSource = "icon_source"
        case groupAdjacentWindows = "group_adjacent_windows"
        case fontSize = "font_size"
        case cornerRoundness = "corner_roundness"
        case dimFactor = "dim_factor"
        case itemColor = "item_color"
        case fillColor = "fill_color"
        case activeItemColor = "active_item_color"
        case highlightColor = "highlight_color"
        case hoverFillColor = "hover_fill_color"
        case hoverItemColor = "hover_item_color"
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
        edge =
            try container.decodeIfPresent(
                AppBarEdge.self,
                forKey: .edge
            ) ?? defaults.edge
        alignment =
            try container.decodeIfPresent(
                BarAlignment.self,
                forKey: .alignment
            ) ?? defaults.alignment
        thickness = max(
            Self.minThickness,
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .thickness
            ) ?? defaults.thickness
        )
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
        // Decoded as a raw String, never as `Content.self`: a
        // value this enum no longer knows — the retired
        // `name` / `icon_and_name`, or a hand-edit typo — would
        // otherwise THROW here and take every other bar setting
        // in this struct down with it. Through String it lands
        // on the default instead, so an old profile opens as
        // `icon_and_title` and the user re-picks if they care
        // (AGENTS.md §5: re-editing the config IS the
        // migration). Deliberately unlike the sibling enum
        // fields, which still throw: `content` is the one whose
        // vocabulary was renamed under existing configs.
        // `ContentDecodeFallbackTests` pins both halves.
        content =
            try container.decodeIfPresent(
                String.self,
                forKey: .content
            ).flatMap(Content.init(rawValue:)) ?? defaults.content
        titleCap =
            try container.decodeIfPresent(
                Int.self,
                forKey: .titleCap
            ) ?? defaults.titleCap
        iconSource =
            try container.decodeIfPresent(
                BarAppIconSource.self,
                forKey: .iconSource
            ) ?? defaults.iconSource
        groupAdjacentWindows =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .groupAdjacentWindows
            ) ?? defaults.groupAdjacentWindows
        try decodeAppearance(from: container)
    }

    private mutating func decodeAppearance(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let defaults = Self()
        fontSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .fontSize
            ) ?? defaults.fontSize
        cornerRoundness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRoundness
            ) ?? defaults.cornerRoundness
        dimFactor = Self.clampDim(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .dimFactor
            ) ?? defaults.dimFactor
        )
        itemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .itemColor
            ) ?? defaults.itemColor
        fillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .fillColor
            ) ?? defaults.fillColor
        activeItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .activeItemColor
            ) ?? defaults.activeItemColor
        highlightColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .highlightColor
            ) ?? defaults.highlightColor
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
