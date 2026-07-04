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

// MARK: - Per-mode parameters

/// `new_window_placement`: where a new window lands in a
/// space's flat window array. Every layout shares the same
/// vocabulary; only the default differs per layout.
public enum SpawnPlacement: String, Sendable, Codable {
    /// Index 0 (stack mode: the new window becomes master).
    case first
    /// End of the array.
    case last
    /// Directly before the focused window.
    case beforeFocused = "before_focused"
    /// Directly after the focused window (BSP: the new
    /// window splits the focused window's region).
    case afterFocused = "after_focused"
}

public struct BspParams: Sendable, Equatable, Codable {
    public enum Strategy: String, Sendable, Codable {
        /// Split the longer side (keeps windows square-ish).
        case shortestSide = "shortest_side"
        /// Alternate horizontal / vertical by depth.
        case alternating
    }

    public var strategy: Strategy = .shortestSide
    public var splitRatio: Double = 0.5
    public var newWindowPlacement: SpawnPlacement = .afterFocused

    public init() {}

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        strategy =
            try container.decodeIfPresent(
                Strategy.self,
                forKey: .strategy
            ) ?? .shortestSide
        splitRatio =
            try container.decodeIfPresent(
                Double.self,
                forKey: .splitRatio
            ) ?? 0.5
        newWindowPlacement =
            try container.decodeIfPresent(
                SpawnPlacement.self,
                forKey: .newWindowPlacement
            ) ?? .afterFocused
    }
}

public struct StackParams: Sendable, Equatable, Codable {
    /// What happens when a column can't give every window
    /// `minWindowSize`.
    public enum OverflowStyle: String, Sendable, Codable {
        /// Only the windows that don't fit cascade at the
        /// bottom; the rest stay fully tiled.
        case cascadeOverflow = "cascade_overflow"
        /// The whole zone cascades.
        case cascadeAll = "cascade_all"
    }

    /// Windows 0..<masterCount form the master zone.
    public var masterCount: Int = 1
    /// Width fraction of the master zone.
    public var masterRatio: Double = 0.6
    /// Column overflow behavior (applies to both zones).
    public var overflowStyle: OverflowStyle = .cascadeOverflow
    /// dwm-style default: `.first` makes the new window the
    /// master (the last master slides into the stack).
    public var newWindowPlacement: SpawnPlacement = .first

    public init() {}

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        masterCount =
            try container.decodeIfPresent(
                Int.self,
                forKey: .masterCount
            ) ?? 1
        masterRatio =
            try container.decodeIfPresent(
                Double.self,
                forKey: .masterRatio
            ) ?? 0.6
        overflowStyle =
            try container.decodeIfPresent(
                OverflowStyle.self,
                forKey: .overflowStyle
            ) ?? .cascadeOverflow
        newWindowPlacement =
            try container.decodeIfPresent(
                SpawnPlacement.self,
                forKey: .newWindowPlacement
            ) ?? .first
    }
}

public struct ScrollingParams: Sendable, Equatable, Codable {
    public enum Anchor: String, Sendable, Codable {
        case center
        case left
        case right
    }

    /// Fixed column width for every window.
    public var windowWidth: CGFloat = 800
    /// Where the focused column sits in the viewport.
    public var anchor: Anchor = .center
    /// PaperWM-style default: new columns open next to the
    /// one you are working in.
    public var newWindowPlacement: SpawnPlacement = .afterFocused

    public init() {}

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        windowWidth =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .windowWidth
            ) ?? 800
        anchor =
            try container.decodeIfPresent(
                Anchor.self,
                forKey: .anchor
            ) ?? .center
        newWindowPlacement =
            try container.decodeIfPresent(
                SpawnPlacement.self,
                forKey: .newWindowPlacement
            ) ?? .afterFocused
    }
}

public struct GridParams: Sendable, Equatable, Codable {
    public enum GridType: String, Sendable, Codable {
        case dynamic
        case rigid
    }

    public enum SplitDirection: String, Sendable, Codable {
        /// Column-first progression / horizontal filling.
        case horizontal
        /// Row-first progression / vertical filling.
        case vertical
    }

    public var type: GridType = .dynamic
    public var fillEmptySpace = true
    public var splitDirection: SplitDirection = .horizontal
    /// Rigid grid dimensions.
    public var columns: Int = 3
    public var rows: Int = 2
    /// Grids read as ordered cells: appending keeps every
    /// existing cell in place.
    public var newWindowPlacement: SpawnPlacement = .last

    public init() {}

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        type =
            try container.decodeIfPresent(
                GridType.self,
                forKey: .type
            ) ?? .dynamic
        fillEmptySpace =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .fillEmptySpace
            ) ?? true
        splitDirection =
            try container.decodeIfPresent(
                SplitDirection.self,
                forKey: .splitDirection
            ) ?? .horizontal
        columns =
            try container.decodeIfPresent(
                Int.self,
                forKey: .columns
            ) ?? 3
        rows =
            try container.decodeIfPresent(
                Int.self,
                forKey: .rows
            ) ?? 2
        newWindowPlacement =
            try container.decodeIfPresent(
                SpawnPlacement.self,
                forKey: .newWindowPlacement
            ) ?? .last
    }
}
