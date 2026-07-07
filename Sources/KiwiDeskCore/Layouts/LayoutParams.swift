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
    /// Per-space overrides (`layout.bsp.override[space_id]`),
    /// resolved via `TilingSettings.resolvedBsp(for:)`.
    public var override: [SpaceID: BspOverride] = [:]

    public init() {}

    /// JSON keys follow the Lua setters (`bsp.set_ratio`).
    private enum CodingKeys: String, CodingKey {
        case strategy
        case splitRatio = "ratio"
        case newWindowPlacement = "new_window_placement"
        case override
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
        override =
            try container.decodeIfPresent(
                [SpaceID: BspOverride].self,
                forKey: .override
            ) ?? [:]
    }

    /// Manual encode so the per-space override map stays sparse
    /// (absent when empty), unlike the synthesized encode.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(splitRatio, forKey: .splitRatio)
        try container.encode(
            newWindowPlacement,
            forKey: .newWindowPlacement
        )
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
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
    /// Per-space overrides (`layout.stack.override[space_id]`),
    /// resolved via `TilingSettings.resolvedStack(for:)`.
    public var override: [SpaceID: StackOverride] = [:]

    public init() {}

    /// JSON keys follow the Lua setters (`stack.set_*`).
    private enum CodingKeys: String, CodingKey {
        case masterCount = "master_count"
        case masterRatio = "master_ratio"
        case overflowStyle = "overflow_style"
        case newWindowPlacement = "new_window_placement"
        case override
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
        override =
            try container.decodeIfPresent(
                [SpaceID: StackOverride].self,
                forKey: .override
            ) ?? [:]
    }

    /// Manual encode so the per-space override map stays sparse
    /// (absent when empty), unlike the synthesized encode.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(masterCount, forKey: .masterCount)
        try container.encode(masterRatio, forKey: .masterRatio)
        try container.encode(
            overflowStyle,
            forKey: .overflowStyle
        )
        try container.encode(
            newWindowPlacement,
            forKey: .newWindowPlacement
        )
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
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

    /// Fixed slot size along the scroll axis (column width when
    /// horizontal, row height when vertical). `auto` by default,
    /// resolving to an orientation-aware standard at layout time.
    public var slotSize: ScrollSize = .auto
    /// Where the focused column sits in the viewport.
    public var anchor: Anchor = .center
    public var orientation: Orientation = .horizontal
    /// PaperWM-style default: new columns open next to the
    /// one you are working in.
    public var newWindowPlacement: SpawnPlacement = .afterFocused
    public var appBar = LayoutAppBar()
    /// Per-space overrides (`layout.scroll.override[space_id]`),
    /// resolved via `TilingSettings.resolvedScrolling(for:)`.
    public var override: [SpaceID: ScrollingOverride] = [:]

    public init() {}

    /// AppBarHosting: the bar axis follows the scroll axis.
    public var barAxisIsHorizontal: Bool {
        orientation == .horizontal
    }

    /// JSON keys follow the Lua setters (`scroll.set_slot_size`).
    private enum CodingKeys: String, CodingKey {
        case slotSize = "slot_size"
        case anchor
        case orientation
        case newWindowPlacement = "new_window_placement"
        case appBar = "app_bar"
        case override
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        slotSize =
            try container.decodeIfPresent(
                ScrollSize.self,
                forKey: .slotSize
            ) ?? .auto
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
        override =
            try container.decodeIfPresent(
                [SpaceID: ScrollingOverride].self,
                forKey: .override
            ) ?? [:]
    }

    /// Manual encode so the per-space override map stays sparse
    /// (absent when empty), unlike the synthesized encode.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slotSize, forKey: .slotSize)
        try container.encode(anchor, forKey: .anchor)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(
            newWindowPlacement,
            forKey: .newWindowPlacement
        )
        try container.encode(appBar, forKey: .appBar)
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
    }
}
