import CoreGraphics
import Foundation

/// Pure function layout algorithm from flat window array to geometry.
public protocol LayoutSystem: Sendable {
    /// Computes frames for tiled windows inside context bounds.
    func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect]
}

/// Gap configuration with outer edge gaps and inner inter-window gaps.
public struct Gaps: Sendable, Equatable, Codable {
    public struct Outer: Sendable, Equatable, Codable {
        public var top: CGFloat
        public var bottom: CGFloat
        public var left: CGFloat
        public var right: CGFloat

        public init(
            top: CGFloat = 10,
            bottom: CGFloat = 10,
            left: CGFloat = 10,
            right: CGFloat = 10
        ) {
            self.top = top
            self.bottom = bottom
            self.left = left
            self.right = right
        }
    }

    public struct Inner: Sendable, Equatable, Codable {
        /// Gap between side-by-side windows (columns).
        public var horizontal: CGFloat
        /// Gap between stacked windows (rows).
        public var vertical: CGFloat

        /// The 10 pt default couples to `BorderStyle.width` (5):
        /// two neighbouring rings each reach their width into this
        /// gap, so 2 × 5 fills it without overlap. Lowering it
        /// silently invalidates that rationale — revisit the width
        /// default and its docs together.
        public init(
            horizontal: CGFloat = 10,
            vertical: CGFloat = 10
        ) {
            self.horizontal = horizontal
            self.vertical = vertical
        }
    }

    public var outer: Outer
    public var inner: Inner

    public init(outer: Outer = Outer(), inner: Inner = Inner()) {
        self.outer = outer
        self.inner = inner
    }

    /// One value for all six gaps (`set_gap_global`).
    public static func uniform(_ value: CGFloat) -> Gaps {
        Gaps(
            outer: Outer(
                top: value,
                bottom: value,
                left: value,
                right: value
            ),
            inner: Inner(horizontal: value, vertical: value)
        )
    }
}

/// Geometry and parameters context for layout calculation.
public struct LayoutContext: Sendable {
    /// Usable screen area in layout coordinates.
    public var bounds: CGRect
    /// Resolved gaps for this space (override > global).
    public var gaps: Gaps
    /// Focused window or pan anchor (#431, #881).
    public var focused: WindowID?
    /// Overlap Stack trigger dimension threshold.
    public var minWindowSize: CGFloat
    /// Stack column share per window (#67).
    public var stackWeights: [WindowID: Double]
    /// Viewport offset and anchor slot from last scrolling tile (#66, #966).
    public var scrollRest: ScrollRest?
    /// Track layout break markers (#128).
    public var trackBreaks: Set<WindowID>
    /// Track column weights (#128).
    public var trackWeights: [WindowID: Double]
    /// Sticky windows exempt from overlap piling (#414). May
    /// contain ids not in the passed window array (floating
    /// stickies); layouts only test membership against the ids
    /// they were handed, so the over-approximation is harmless.
    public var sticky: Set<WindowID>
    /// Screen neighbor topology for clamping and park corners (#878, #881).
    public var screenNeighbors: ScreenNeighbors
    /// App-enforced size bounds confirmed by engine (#677).
    public var sizeBounds: [WindowID: EffectiveSizeBound]

    /// Bypasses the GENERALIZED size-bound arm on a forced,
    /// explicit-apply pass (#1055, owner ruling 2026-08-28) — an
    /// explicit set past a corroborated bound genuinely re-asks
    /// the app once. The probe self-terminates: the refusal it
    /// observes mints the exact entry the next un-forced pass
    /// consumes.
    public var probesBeyondBounds = false

    public var bsp: BspParams
    public var stack: StackParams
    public var scrolling: ScrollingParams
    public var grid: GridParams
    public var monocle: MonocleParams
    public var track: TrackParams
    /// Global indicator bar style for strip reservation.
    public var appBarStyle: AppBarStyle

    public init(
        bounds: CGRect,
        gaps: Gaps = Gaps(),
        focused: WindowID? = nil,
        minWindowSize: CGFloat = 300,
        stackWeights: [WindowID: Double] = [:],
        scrollRest: ScrollRest? = nil,
        trackBreaks: Set<WindowID> = [],
        trackWeights: [WindowID: Double] = [:],
        sticky: Set<WindowID> = [],
        screenNeighbors: ScreenNeighbors = ScreenNeighbors(),
        sizeBounds: [WindowID: EffectiveSizeBound] = [:],
        bsp: BspParams = BspParams(),
        stack: StackParams = StackParams(),
        scrolling: ScrollingParams = ScrollingParams(),
        grid: GridParams = GridParams(),
        monocle: MonocleParams = MonocleParams(),
        track: TrackParams = TrackParams(),
        appBarStyle: AppBarStyle = AppBarStyle()
    ) {
        self.bounds = bounds
        self.gaps = gaps
        self.focused = focused
        self.minWindowSize = minWindowSize
        self.stackWeights = stackWeights
        self.scrollRest = scrollRest
        self.trackBreaks = trackBreaks
        self.trackWeights = trackWeights
        self.sticky = sticky
        self.screenNeighbors = screenNeighbors
        self.sizeBounds = sizeBounds
        self.bsp = bsp
        self.stack = stack
        self.scrolling = scrolling
        self.grid = grid
        self.monocle = monocle
        self.track = track
        self.appBarStyle = appBarStyle
    }

    /// Screen bounds inset by the per-edge outer gaps.
    public var usable: CGRect {
        let outer = gaps.outer
        return CGRect(
            x: bounds.minX + outer.left,
            y: bounds.minY + outer.top,
            width: bounds.width - outer.left - outer.right,
            height: bounds.height - outer.top - outer.bottom
        )
    }
}
