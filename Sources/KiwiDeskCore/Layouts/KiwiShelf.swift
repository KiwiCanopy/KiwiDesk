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
    /// The Space Bar's percentage of the edge once BOTH bars
    /// overflow; a bar needing less gives the rest back.
    public var share: CGFloat = 40
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

    public init() {}

    /// Floor of `thickness` (QA 2026-07-19): below it the plate
    /// stroke and glyph run collide. Decode, setter and the GUI
    /// slider all derive from it (#1359, `BarSliderBandTests`).
    public static let minThickness: CGFloat = 20
    /// A margin's floor (#1516): flush.
    public static let minMargin: CGFloat = 0
    /// Bounds of `share` in percent.
    public static let shareRange: ClosedRange<CGFloat> = 20...80

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

    /// True if the plate spans edge-to-edge — the SETTINGS
    /// PREVIEWS' one copy of the spans rule; the live bars resolve
    /// one layer down in `BarPlate.frame`, which adds the
    /// hug→full overflow fallback, so retune the two together.
    public var plateSpans: Bool {
        !hasBox && backgroundFit == .full
    }

    /// `share` clamped to `shareRange`.
    public var resolvedShare: CGFloat {
        min(
            max(share, Self.shareRange.lowerBound),
            Self.shareRange.upperBound
        )
    }

    /// Concrete corner radius in pt for a given thickness.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }
}

extension KiwiShelf: Codable {}
