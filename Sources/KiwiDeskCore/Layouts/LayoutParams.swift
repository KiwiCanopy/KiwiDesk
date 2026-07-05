import CoreGraphics
import Foundation

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

    /// JSON keys follow the Lua setters (`bsp.set_ratio`).
    private enum CodingKeys: String, CodingKey {
        case strategy
        case splitRatio = "ratio"
        case newWindowPlacement = "new_window_placement"
    }

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

    /// JSON keys follow the Lua setters (`stack.set_*`).
    private enum CodingKeys: String, CodingKey {
        case masterCount = "master_count"
        case masterRatio = "master_ratio"
        case overflowStyle = "overflow_style"
        case newWindowPlacement = "new_window_placement"
    }

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

public struct ScrollingParams: Sendable, Equatable, Codable,
    AppBarHosting
{
    public enum Anchor: String, Sendable, Codable {
        case center
        case left
        case right
    }

    /// Which axis the columns scroll along — the scrolling
    /// analogue of monocle's orientation, and what decides
    /// which edges the indicator bar may sit on.
    public enum Orientation: String, Sendable, Codable {
        /// Columns side by side, scrolling left/right; bar on
        /// top/bottom.
        case horizontal
        /// Rows stacked, scrolling up/down; bar on left/right.
        case vertical
    }

    /// Fixed column width for every window (the extent across
    /// the scroll axis: width when horizontal, height when
    /// vertical).
    public var windowWidth: CGFloat = 800
    /// Where the focused column sits in the viewport.
    public var anchor: Anchor = .center
    public var orientation: Orientation = .horizontal
    /// PaperWM-style default: new columns open next to the
    /// one you are working in.
    public var newWindowPlacement: SpawnPlacement = .afterFocused
    public var appBar = LayoutAppBar()

    public init() {}

    /// AppBarHosting: the bar axis follows the scroll axis.
    public var barAxisIsHorizontal: Bool {
        orientation == .horizontal
    }

    /// JSON keys follow the Lua setters (`scroll.set_width`).
    private enum CodingKeys: String, CodingKey {
        case windowWidth = "width"
        case anchor
        case orientation
        case newWindowPlacement = "new_window_placement"
        case appBar = "app_bar"
    }

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
        orientation =
            try container.decodeIfPresent(
                Orientation.self,
                forKey: .orientation
            ) ?? .horizontal
        newWindowPlacement =
            try container.decodeIfPresent(
                SpawnPlacement.self,
                forKey: .newWindowPlacement
            ) ?? .afterFocused
        appBar =
            try container.decodeIfPresent(
                LayoutAppBar.self,
                forKey: .appBar
            ) ?? LayoutAppBar()
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

    /// JSON keys follow the Lua setters (`grid.set_*`).
    private enum CodingKeys: String, CodingKey {
        case type
        case fillEmptySpace = "fill_empty_space"
        case splitDirection = "split_direction"
        case columns
        case rows
        case newWindowPlacement = "new_window_placement"
    }

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
