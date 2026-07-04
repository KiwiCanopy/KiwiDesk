import CoreGraphics
import Foundation

/// A layout algorithm: a pure function from a flat window array
/// to per-window geometry. No trees, no containers — this is the
/// core KiwiDesk idea (see 01_Manifest).
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
    /// Focused window (drives Scrolling and Monocle ordering).
    public var focused: WindowID?
    /// Below this width/height the Overlap Stack kicks in.
    public var minWindowSize: CGFloat

    public var bsp: BspParams
    public var stack: StackParams
    public var scrolling: ScrollingParams
    public var grid: GridParams

    public init(
        bounds: CGRect,
        gaps: Gaps = Gaps(),
        focused: WindowID? = nil,
        minWindowSize: CGFloat = 300,
        bsp: BspParams = BspParams(),
        stack: StackParams = StackParams(),
        scrolling: ScrollingParams = ScrollingParams(),
        grid: GridParams = GridParams()
    ) {
        self.bounds = bounds
        self.gaps = gaps
        self.focused = focused
        self.minWindowSize = minWindowSize
        self.bsp = bsp
        self.stack = stack
        self.scrolling = scrolling
        self.grid = grid
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
