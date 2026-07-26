import CoreGraphics
import Foundation

/// A layout algorithm: a pure function from a flat window array
/// to per-window geometry. No trees, no containers — this is the
/// core KiwiDesk idea.
public protocol LayoutSystem: Sendable {
    /// Calculates frames for tiled windows inside the context's
    /// bounds. Windows not present in the result keep their
    /// current frame (e.g. floating mode returns [:]).
    func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect]
}

/// Gap configuration (Rift-style): outer gaps per screen edge,
/// inner gaps between adjacent windows.
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

        /// The 10 pt default couples to `BorderStyle.width` (5 pt):
        /// two neighbouring focus rings each reach their width into
        /// this gap, so `2 × 5 = 10` fills it edge-to-edge without
        /// overlap. Lowering this default silently invalidates that
        /// rationale (rings would overlap with unfocused borders on) —
        /// revisit the width default and its docs if you change it.
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

/// Everything a layout needs to compute geometry.
public struct LayoutContext: Sendable {
    /// Usable screen area in layout coordinates.
    public var bounds: CGRect
    /// Resolved gaps for this space (override > global).
    public var gaps: Gaps
    /// The window Scrolling pans to. A render/pan anchor that may
    /// diverge from the space's own focus: it can carry a
    /// tiled-sticky traveler that is the frontmost window but not
    /// the membership-guarded `focused` slot (#431,
    /// `StateCoordinator.focusAnchor`). Only Scrolling reads it —
    /// Monocle's raise resolves the anchor itself
    /// (`restoreMonocleZOrder`), it does not read this field.
    public var focused: WindowID?
    /// Below this width/height the Overlap Stack kicks in.
    public var minWindowSize: CGFloat
    /// Per-window vertical share of a stack column (#67);
    /// absent = 1.0. Snapshot of `Space.stackWeights`.
    public var stackWeights: [WindowID: Double]
    /// The scrolling layout's viewport offset from the last
    /// tile (#66); `nil` before the space has ever scrolled.
    /// Snapshot of `Space.scrollOffset`.
    public var scrollOffset: CGFloat?
    /// The track layout's break markers (#128): a window in the
    /// set starts a new track (`TrackLayout.counts`). Snapshot
    /// of `Space.trackBreaks`.
    public var trackBreaks: Set<WindowID>
    /// Per-track size weight, keyed by the track's head window
    /// (#128). Snapshot of `Space.trackWeights`.
    public var trackWeights: [WindowID: Double]
    /// Sticky windows (#414 v2): members here keep a fully
    /// tiled slot when a layout overflows into an
    /// `OverlapStack` pile (`OverlapStack.stickyExempt`) —
    /// a non-sticky window overflows instead. May contain ids
    /// not in the passed window array (floating stickies);
    /// layouts only ever test membership against the ids they
    /// were handed, so the over-approximation is harmless.
    public var sticky: Set<WindowID>

    public var bsp: BspParams
    public var stack: StackParams
    public var scrolling: ScrollingParams
    public var grid: GridParams
    public var monocle: MonocleParams
    public var track: TrackParams
    /// The indicator bar's global look; a layout resolves its
    /// own bar against this to carve the strip.
    public var appBarStyle: AppBarStyle

    public init(
        bounds: CGRect,
        gaps: Gaps = Gaps(),
        focused: WindowID? = nil,
        minWindowSize: CGFloat = 300,
        stackWeights: [WindowID: Double] = [:],
        scrollOffset: CGFloat? = nil,
        trackBreaks: Set<WindowID> = [],
        trackWeights: [WindowID: Double] = [:],
        sticky: Set<WindowID> = [],
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
        self.scrollOffset = scrollOffset
        self.trackBreaks = trackBreaks
        self.trackWeights = trackWeights
        self.sticky = sticky
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
