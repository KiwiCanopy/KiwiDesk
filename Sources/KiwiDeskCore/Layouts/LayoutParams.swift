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
        case longestSide = "longest_side"
        /// Alternate horizontal / vertical by depth.
        case alternating
    }

    public var strategy: Strategy = .longestSide
    /// Ratio of every side-by-side split (#56). `resize("x")`
    /// nudges this one; the stacked splits keep their own.
    public var splitRatioH: Double = 0.5
    /// Ratio of every stacked (top/bottom) split (#56), moved
    /// by `resize("y")` — independent of the side-by-side one.
    public var splitRatioV: Double = 0.5
    public var newWindowPlacement: SpawnPlacement = .afterFocused
    /// Per-space overrides (`layout.bsp.override[space_id]`),
    /// resolved via `TilingSettings.resolvedBsp(for:)`.
    public var override: [SpaceID: BspOverride] = [:]

    public init() {}

    /// JSON keys follow the Lua setters (`bsp.set_ratio_h`).
    private enum CodingKeys: String, CodingKey {
        case strategy
        case splitRatioH = "ratio_h"
        case splitRatioV = "ratio_v"
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
            ) ?? .longestSide
        splitRatioH =
            try container.decodeIfPresent(
                Double.self,
                forKey: .splitRatioH
            ) ?? 0.5
        splitRatioV =
            try container.decodeIfPresent(
                Double.self,
                forKey: .splitRatioV
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
        try container.encode(splitRatioH, forKey: .splitRatioH)
        try container.encode(splitRatioV, forKey: .splitRatioV)
        try container.encode(
            newWindowPlacement,
            forKey: .newWindowPlacement
        )
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
    }
}

// `StackParams` lives in `StackParams.swift` (#222 split).

public struct ScrollingParams: Sendable, Equatable, Codable,
    AppBarHosting
{
    /// Where the focused slot rests in the viewport, applied on
    /// every focus change (#239).
    public enum Anchor: String, Sendable, Codable {
        /// Focused slot centred in the viewport.
        case center
        /// Flush against the leading edge of the scroll axis —
        /// left when horizontal, top when vertical. Axis-relative
        /// like `AppBarStyle.Position`, so it lands where the GUI
        /// label says on either orientation.
        case start
        /// Flush against the trailing edge (right / bottom).
        case end
        /// Keep the prior viewport offset and pan the minimum
        /// needed to reveal the focused slot (#66 Niri/PaperWM
        /// scroll-into-view). The only anchor that reads the
        /// previous offset; the side you came from stays open.
        case follow
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
    /// Where the focused column rests in the viewport (#239).
    /// `follow` by default: keeps today's minimal-pan feel — the
    /// viewport holds still and pans only to reveal the focus.
    public var anchor: Anchor = .follow
    public var orientation: Orientation = .horizontal
    /// PaperWM-style default: new columns open next to the
    /// one you are working in.
    public var newWindowPlacement: SpawnPlacement = .afterFocused
    /// Whether stepping `focus` past a row end wraps to the far
    /// end (#168). OFF by default: the stop-at-ends default
    /// matches the physical-strip feel of the layout — the row
    /// has real ends, so focus stopping there reads as reaching
    /// the edge, not a dead input. Monocle wraps unconditionally
    /// (all windows share one frame, so there is no strip to
    /// end); scrolling makes it opt-in. `swap` never wraps (see
    /// `scrollingStep`).
    public var wrapFocus = false
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
        case wrapFocus = "wrap_focus"
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
            ) ?? .follow
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
        wrapFocus =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .wrapFocus
            ) ?? false
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
        try container.encode(wrapFocus, forKey: .wrapFocus)
        try container.encode(appBar, forKey: .appBar)
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
    }
}
