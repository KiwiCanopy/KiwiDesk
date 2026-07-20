import CoreGraphics
import Foundation

/// The app bar's global look, shared by every layout that
/// shows a bar (monocle, scrolling). Stored top-level as
/// `app_bar` in profile JSON, set from Lua via `app_bar.set_*`.
/// A layout may
/// override any of these fields for itself (see `LayoutAppBar`);
/// what isn't overridden inherits from here.
///
/// Two things deliberately live *outside* this type because they
/// are layout-specific, not looks: whether the bar is shown
/// (`LayoutAppBar.enabled`) and the focus/scroll axis
/// (`MonocleParams.orientation` / `ScrollingParams.orientation`).
public struct AppBarStyle: Sendable, Equatable {
    /// The absolute screen edge the bar occupies (#293) — no
    /// longer derived from the layout's axis.
    public var edge: AppBarEdge = .top
    /// Item-group placement along the bar; center matches the
    /// pre-#293-QA shipped behavior.
    public var alignment: BarAlignment = .center
    /// Depth of the reserved strip (pt).
    public var thickness: CGFloat = 32
    public var tabBackground: TabBackground = .boxed
    /// Liquid Glass finish (macOS 26+), orthogonal to the shape:
    /// a colorless glass material laid over the Boxed boxes or the
    /// Plain plate. Ignored below macOS 26 (`glassEnabled`). Fill
    /// is still forwarded as the glass tint, though the tint reads
    /// near-colorless on current macOS (#390).
    public var liquidGlass: Bool = false
    /// Hug by default: a tight plate reads calmer than an
    /// edge-to-edge strip (ui-designer, QA 2026-07-19).
    public var tabBackgroundFit: TabBackgroundFit = .hug
    public var activeIndicator: ActiveIndicator = .outline
    /// Item length along the bar (pt) — every item is the
    /// same size. 0 (default) = a standard length per
    /// `content`: a compact square for icon-only, wider once
    /// text is shown. Clamped at layout time between the icon
    /// square (icons never clip) and a quarter of the bar;
    /// items that overflow anyway scroll instead of shrinking.
    public var boxSize: CGFloat = 0
    /// Spacing between boxes (pt); 0 = touching.
    public var boxGap: CGFloat = 6
    public var content: Content = .iconAndName
    /// Where app icons come from: the native app image, or a
    /// monochrome SketchyBar App Font glyph that follows the
    /// bar's text colors (#294). Apps without a glyph keep
    /// their image.
    public var iconSource: BarAppIconSource = .appImage
    /// Adjacent windows of the same app collapse into one
    /// item wearing a count badge. Clicking the group
    /// focuses its first member, which expands the group
    /// into individual items; focus leaving the group
    /// collapses it again. Non-adjacent windows of the same
    /// app stay separate items.
    public var groupAdjacentWindows = true
    /// 0 (default) = auto: the text scales with the bar
    /// thickness. Any positive value pins the size.
    public var fontSize: CGFloat = 0
    /// Corner rounding as a percentage (0–100) of the maximum:
    /// 100 = a full capsule (radius = thickness/2), 0 = square.
    /// Resolved to a concrete radius in
    /// `resolvedCornerRadius(forThickness:)`. Percentage, not
    /// pt, so it can't exceed thickness/2 (which rendered tabs
    /// as pointed hexagons) and self-adapts to any thickness.
    public var cornerRoundness: CGFloat = 50
    /// Opacity of an inactive tab's untinted icon (0.05–1). The dim
    /// carries "not focused" for content that takes no state color.
    /// Lua-only power knob (`set_dim_factor`, no GUI); the default
    /// matches `BarAccent.untintedAlpha`. Clamped in `resolvedDim`.
    public var dimFactor: CGFloat = BarAccent.untintedAlpha
    /// Kiwi theme: cream item text/glyph, a translucent
    /// dark-moss fill (box, plate, or glass tint), a flesh-green
    /// active accent — one green family, not the old brown/green
    /// pair (2026-07-20; brown fully retired, drag visuals now
    /// green/amber).
    public var itemColor = "#F2EBD9"
    /// The fill under the items — a box per item (Boxed), one
    /// shared plate (Plain), or the Liquid Glass tint
    /// (Material). One knob, three renders.
    public var fillColor = "#37452E66"
    public var activeItemColor = "#4E9F3D"
    public var highlightColor = "#4E9F3D"
    /// Hover feedback on clickable (non-active) items: a
    /// lighter, translucent kiwi green, deliberately a shade
    /// off the highlight so hover and active never read as
    /// the same state.
    public var hoverFillColor = "#6DBF5B80"
    /// Item text/glyph while hovered; defaults to the normal
    /// item color (the hover tint is translucent, so cream
    /// stays readable through it) — the knob exists for themes
    /// whose hover tint needs darker text.
    public var hoverItemColor = "#F2EBD9"
    /// The count badge on grouped items.
    public var groupBadgeColor = "#B00020"
    public var groupBadgeTextColor = "#FFFFFF"

    public init() {}

    /// The concrete corner radius (pt) for a tab/strip of the
    /// given cross dimension: `cornerRoundness`% of its half —
    /// 100% is a capsule, 0% square. One resolution site shared
    /// by the item box, the shared strip, the scroll arrows, and
    /// the GUI preview so they can't drift.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }

    /// Guards a dim factor to a legible, sane range — the only
    /// restriction on the Lua-only knob (a fully invisible or >1
    /// alpha is a bug, not a preference). No ordering is enforced
    /// across the Space Bar's two factors: Lua users may set what
    /// they want; the GUI is the curated gate, Lua the open one.
    public static func clampDim(_ value: CGFloat) -> CGFloat {
        max(0.05, min(value, 1))
    }

    /// The Liquid Glass finish is painted only where the platform
    /// can render it — false below macOS 26 even if `liquidGlass`
    /// is stored true, so a glass profile opened on older macOS
    /// shows the solid shape (the toggle is hidden there too).
    public var glassEnabled: Bool {
        liquidGlass && Self.glassAvailable
    }

    /// An item paints its own box: the Boxed shape without the
    /// glass finish. Plain (shared plate) and any glass finish
    /// draw no per-item box, so item fill/accent geometry that
    /// keyed on "boxed" keys on this instead.
    public var hasBox: Bool {
        tabBackground == .boxed && !glassEnabled
    }
}

// MARK: - Codable

extension AppBarStyle: Codable {
    /// JSON keys are the Lua setters (`app_bar.set_*`) minus the
    /// `set_` verb — the `app_bar` nesting carries the namespace.
    /// `CaseIterable` is load-bearing: the parity test
    /// (`AppBarParityTests`) reflects over `allCases` to prove
    /// every field has a key — do not drop it as "unused".
    enum CodingKeys: String, CodingKey, CaseIterable {
        case edge
        case alignment
        case thickness
        case tabBackground = "tab_background"
        case liquidGlass = "liquid_glass"
        case tabBackgroundFit = "tab_background_fit"
        case activeIndicator = "active_indicator"
        case boxSize = "box_size"
        case boxGap = "box_gap"
        case content
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
        tabBackground =
            try container.decodeIfPresent(
                TabBackground.self,
                forKey: .tabBackground
            ) ?? defaults.tabBackground
        liquidGlass =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .liquidGlass
            ) ?? defaults.liquidGlass
        tabBackgroundFit =
            try container.decodeIfPresent(
                TabBackgroundFit.self,
                forKey: .tabBackgroundFit
            ) ?? defaults.tabBackgroundFit
        activeIndicator =
            try container.decodeIfPresent(
                ActiveIndicator.self,
                forKey: .activeIndicator
            ) ?? defaults.activeIndicator
        boxSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .boxSize
            ) ?? defaults.boxSize
        boxGap =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .boxGap
            ) ?? defaults.boxGap
        content =
            try container.decodeIfPresent(
                Content.self,
                forKey: .content
            ) ?? defaults.content
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
