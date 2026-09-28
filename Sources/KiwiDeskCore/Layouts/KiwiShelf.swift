import CoreGraphics
import Foundation

/// The shelf the bars sit on (#1517): how deep, how the two share
/// an edge, and the look they share. Which edge is each bar's own
/// (#1731) — one edge fuses them onto this shelf, two split it. Stored as
/// `kiwishelf` in profile JSON; each bar keeps only what is its
/// own (`SpaceBarStyle`, `AppBarStyle`), and a drawing reads the
/// two through `SpaceBarLook` / `AppBarLook`.
public struct KiwiShelf: Sendable, Equatable {
    public typealias BackgroundStyle = AppBarStyle.BackgroundStyle
    public typealias BackgroundFit = AppBarStyle.BackgroundFit
    public typealias Alignment = AppBarStyle.BarAlignment

    /// Which bar takes the start of the edge while both show.
    public enum Order: String, Sendable, Codable, CaseIterable {
        case spacesFirst = "spaces_first"
        case appsFirst = "apps_first"
    }

    /// Where a bar sits along its edge (center, #293 QA): a lone
    /// bar, both as one unit on a shared edge, or each bar on its
    /// own edge while split (#1731).
    public var alignment: Alignment = .center
    /// Bar order while both show on one edge.
    public var order: Order = .spacesFirst
    /// The Space Bar's floor, in percent of the edge, once the
    /// shelf is full: it shrinks no further, and the App Bar
    /// scrolls instead. A floor on shrinking, never a length it is
    /// padded up to — a Space Bar needing less keeps its need.
    public var minimum: CGFloat = 30
    /// Depth of the strip (pt): 40 on every screen class (owner
    /// ruling 2026-09-13, #1359; `BarThicknessDefaultTests`).
    public var thickness: CGFloat = 40
    /// Distance from the screen border (pt); 0 is flush (#1516).
    public var outerMargin: CGFloat = 0
    /// Extra room on the window side (pt), ADDED to the windows'
    /// outer gap, which alone keeps the focus ring's clearance
    /// (#1516).
    public var innerMargin: CGFloat = 0
    /// Plain plate or one box per item (plain, #660).
    public var backgroundStyle: BackgroundStyle = .plain
    /// Liquid Glass finish (macOS 26+, #390). On by default (owner
    /// ruling 2026-09-10); inert below 26 via `glassEnabled`.
    public var liquidGlass = true
    /// Plate hugs each bar, or one plate spans the edge.
    public var backgroundFit: BackgroundFit = .hug
    /// Corner rounding percentage (0–100) of thickness / 2.
    public var cornerRoundness: CGFloat = 50
    /// A stroke on the plate's edge — each box's under Boxed —
    /// off by default (#1679). A drawing reads `drawnBorderWidth`.
    public var border = false
    /// The border's stroke (pt), kept while `border` is off.
    public var borderWidth: CGFloat = 1
    /// The active indicator's weight (pt): the outline's stroke,
    /// the edge mark at `edgeMarkRatio` of it (#1680). A drawing
    /// reads `resolvedHighlightWidth`, whatever wrote this.
    public var highlightWidth: CGFloat = 2
    /// Spacing between items in pt — one rhythm for both bars.
    public var itemGap: CGFloat = 6
    /// How large an item's content draws across the shelf, in pt
    /// (#1713): 0 = automatic, the full thickness. Stored as typed;
    /// a drawing reads `contentDepth(forDepth:)`, which clamps it.
    public var glyphSize: CGFloat = 0
    /// Font size in pt; 0 = auto, each bar scaling with thickness.
    public var fontSize: CGFloat = 0
    /// Bar text's family (#1681): an installed family's name, or
    /// `systemFontFamily` / `systemMonospacedFontFamily`. Resolved
    /// at render time (`BarFont`), so a missing one draws System.
    public var fontFamily = KiwiShelf.systemFontFamily
    /// Bar text's weight, 100–900 (#1681). Stored as asked and
    /// resolved at render time, never on write, so a family
    /// switch keeps it.
    public var fontWeight = BarFontWeight.regular.value
    /// App icon rendering: native image or App Font glyph (#294).
    public var iconSource: BarAppIconSource = .appImage
    /// Opacity (0.05–1) of UNTINTED idle content — emoji and app
    /// images, which keep their own colours
    /// (`BarAccent.untintedAlpha`). Tinted idle identifiers take
    /// `idleItemAlpha` instead.
    public var dimFactor: CGFloat = BarAccent.untintedAlpha
    /// Item text and glyph colour. The colour defaults are
    /// mirrored as examples in docs/lua-reference.md — change both.
    public var itemColor = "#EAF3EE"
    /// Active item colour.
    public var activeItemColor = "#8DB354"
    /// The active indicator's colour, both bars' (#1517).
    public var highlightColor = "#8DB354"
    /// Hover fill and item colours on non-active items.
    public var hoverFillColor = "#AACB5D80"
    public var hoverItemColor = "#EAF3EE"
    /// The plate's one fill (#660, retuned by #755;
    /// `PaletteBarFillTests`).
    public var fillColor = "#14201CB3"
    /// The border's colour (#1679): `itemColor`'s hex at alpha
    /// 0x59, spelled out (`ShelfBorderTests` pins the relation) and
    /// held against the wallpaper the plate blends into
    /// (`ShelfBorderContrastTests`).
    public var borderColor = "#EAF3EE59"
    /// Group count badge colours (#955).
    public var groupBadgeColor = "#636366"
    public var groupBadgeTextColor = "#FFFFFF"

    public init() {}

    /// Floor of `thickness` (QA 2026-07-19): below it the plate
    /// stroke and glyph run collide. Decode, setter and the GUI
    /// slider all derive from it (#1359, `BarSliderBandTests`).
    public static let minThickness: CGFloat = 20
    /// A margin's floor (#1516): flush.
    public static let minMargin: CGFloat = 0
    /// The item gap's floor: flush. Decode and setter apply it;
    /// no ceiling (#1695).
    public static let minItemGap: CGFloat = 0
    /// The thinnest content an item draws (#1682): what the
    /// thinnest shelf draws, so a glyph size never takes a glyph
    /// below a size QA already ruled readable.
    public static let minContentDepth: CGFloat = minThickness
    /// An automatic title's size per point of content depth, both
    /// bars' (#1682).
    public static let autoTitleShare: CGFloat = 0.42
    /// Bounds of `highlightWidth` in pt (#1680).
    public static let highlightWidthRange: ClosedRange<CGFloat> = 1...6
    /// The edge mark's thickness per point of `highlightWidth`:
    /// the default 2 draws today's 3 pt mark beside the 2 pt ring.
    public static let edgeMarkRatio: CGFloat = 1.5
    /// Bounds of `borderWidth` in pt (#1679).
    public static let borderWidthRange: ClosedRange<CGFloat> = 1...4
    /// Bounds of `minimum` in percent.
    public static let minimumRange: ClosedRange<CGFloat> = 20...80
    /// Alpha of `itemColor` on an idle Space identifier — a rule,
    /// not a colour (#1517): at it every bundled palette's idle
    /// identifier holds `idleInkFloor` on its plate over white and
    /// black wallpaper (`IdleItemContrastTests`).
    public static let idleItemAlpha: CGFloat = 0.6

    /// The depth the shelf reserves off its edge — outer margin,
    /// strip and inner margin (#1516).
    public var reservation: CGFloat {
        outerMargin + thickness + innerMargin
    }

    /// True if Liquid Glass is on and the platform draws it.
    public var glassEnabled: Bool {
        liquidGlass && AppBarStyle.glassAvailable
    }

    /// An item paints its own box: Boxed shape, no glass finish.
    public var hasBox: Bool {
        backgroundStyle == .boxed && !glassEnabled
    }

    /// Whether the shelf draws a plate at all — the ONE answer
    /// (#1517): Boxed draws a box per item, solid or glass, and no
    /// plate beneath them.
    public var drawsPlate: Bool { backgroundStyle != .boxed }

    /// True if the plate spans edge-to-edge.
    public var plateSpans: Bool {
        drawsPlate && backgroundFit == .full
    }

    /// `minimum` clamped to `minimumRange`.
    public var resolvedMinimum: CGFloat {
        min(
            max(minimum, Self.minimumRange.lowerBound),
            Self.minimumRange.upperBound
        )
    }

    /// An idle Space identifier's ink — `itemColor` at
    /// `idleItemAlpha` of its own alpha, as `#RRGGBBAA`. The one
    /// home the live bar and the Settings preview both read.
    public var idleItemColor: String {
        itemColor(atShare: Self.idleItemAlpha)
    }

    /// `itemColor` at `share` of its own alpha, as `#RRGGBBAA`;
    /// an unparseable colour passes through.
    func itemColor(atShare share: CGFloat) -> String {
        let body = itemColor.uppercased().drop { $0 == "#" }
        guard body.count == 6 || body.count == 8,
            body.allSatisfy(\.isHexDigit)
        else { return itemColor }
        let alpha =
            body.count == 8 ? Int(body.suffix(2), radix: 16) ?? 255 : 255
        let scaled = Int((CGFloat(alpha) * share).rounded())
        return "#" + body.prefix(6) + String(format: "%02X", scaled)
    }

    /// `highlightWidth` clamped to `highlightWidthRange`.
    public static func clampHighlightWidth(_ width: CGFloat) -> CGFloat {
        min(
            max(width, highlightWidthRange.lowerBound),
            highlightWidthRange.upperBound
        )
    }

    /// `highlightWidth` inside `highlightWidthRange` — what every
    /// indicator stroke draws.
    public var resolvedHighlightWidth: CGFloat {
        Self.clampHighlightWidth(highlightWidth)
    }

    /// The edge mark's thickness in pt — the one derivation both
    /// bars' layouts read.
    public var edgeMarkThickness: CGFloat {
        resolvedHighlightWidth * Self.edgeMarkRatio
    }

    /// `borderWidth` clamped to `borderWidthRange`.
    public static func clampBorderWidth(_ width: CGFloat) -> CGFloat {
        min(
            max(width, borderWidthRange.lowerBound),
            borderWidthRange.upperBound
        )
    }

    /// The border stroke every surface draws: 0 while `border` is
    /// off, else `borderWidth` inside its range.
    public var drawnBorderWidth: CGFloat {
        border ? Self.clampBorderWidth(borderWidth) : 0
    }

    /// The depth an item's content is sized to on a strip `depth`
    /// deep (#1682, #1713): the strip's own depth while the glyph
    /// size is automatic, else the glyph size — never thinner than
    /// `minContentDepth` nor deeper than the strip, so a stored
    /// size above a later thickness waits rather than being lost.
    public func contentDepth(forDepth depth: CGFloat) -> CGFloat {
        guard glyphSize > 0 else { return depth }
        return min(depth, max(glyphSize, Self.minContentDepth))
    }

    /// Concrete corner radius in pt for a given thickness.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }
}

extension KiwiShelf: Codable {}
