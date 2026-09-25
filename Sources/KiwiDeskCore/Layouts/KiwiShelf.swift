import CoreGraphics
import Foundation

/// The one shelf both bars sit on (#1517): which edge, how deep,
/// how the two share it, and the look they share. Stored as
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

    /// Absolute screen edge the shelf occupies (top, #660).
    public var edge: AppBarEdge = .top
    /// Where a lone bar sits along the edge (center, #293 QA).
    public var alignment: Alignment = .center
    /// Bar order while both show — they take opposite ends.
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
    /// Spacing between items in pt — one rhythm for both bars.
    public var itemGap: CGFloat = 6
    /// Font size in pt; 0 = auto, each bar scaling with thickness.
    public var fontSize: CGFloat = 0
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
    /// Bounds of `minimum` in percent.
    public static let minimumRange: ClosedRange<CGFloat> = 20...80
    /// Alpha of `itemColor` on an idle Space identifier — a rule,
    /// not a colour (#1517): at it every bundled palette's idle
    /// identifier holds 2.2:1 on its plate over white and black
    /// wallpaper (`IdleItemContrastTests`).
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
        let body = itemColor.uppercased().drop { $0 == "#" }
        guard body.count == 6 || body.count == 8,
            body.allSatisfy(\.isHexDigit)
        else { return itemColor }
        let alpha =
            body.count == 8 ? Int(body.suffix(2), radix: 16) ?? 255 : 255
        let idle = Int((CGFloat(alpha) * Self.idleItemAlpha).rounded())
        return "#" + body.prefix(6) + String(format: "%02X", idle)
    }

    /// Concrete corner radius in pt for a given thickness.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }
}

extension KiwiShelf: Codable {}
