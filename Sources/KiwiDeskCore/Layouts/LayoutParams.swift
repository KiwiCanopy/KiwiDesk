import CoreGraphics
import Foundation

/// Where a new window lands in a space's flat window array
/// (`new_window_placement`).
public enum SpawnPlacement: String, Sendable, Codable, CaseIterable {
    /// Index 0 (master window).
    case first
    /// End of the array.
    case last
    /// Directly before the focused window.
    case beforeFocused = "before_focused"
    /// Directly after the focused window.
    case afterFocused = "after_focused"
}

public struct BspParams: Sendable, Equatable, Codable {
    public enum Strategy: String, Sendable, Codable, CaseIterable {
        /// Split the longer side (keeps windows square-ish).
        case longestSide = "longest_side"
        /// Alternate horizontal / vertical by depth.
        case alternating
    }

    /// How each region is cut. Defaults to `.alternating`
    /// (#1181).
    public var strategy: Strategy = .alternating
    /// Ratio of side-by-side splits (#56).
    public var splitRatioH: Double = 0.5
    /// Ratio of stacked top/bottom splits (#56).
    public var splitRatioV: Double = 0.5
    public var newWindowPlacement: SpawnPlacement = .afterFocused
    /// Per-space overrides resolved via `TilingSettings.resolvedBsp(for:)`.
    public var override: [SpaceID: BspOverride] = [:]

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case strategy
        case splitRatioH = "ratio_h"
        case splitRatioV = "ratio_v"
        case newWindowPlacement = "new_window_placement"
        case override
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        strategy =
            try container.decodeIfPresent(
                Strategy.self,
                forKey: .strategy
            ) ?? .alternating
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

public struct ScrollingParams: Sendable, Equatable, Codable,
    AppBarHosting
{
    /// Viewport resting anchor for focused slot (#239, #753).
    public enum Anchor: String, Sendable, Codable, CaseIterable {
        /// Focused slot centred in the viewport.
        case center
        /// Flush against leading edge (left when horizontal, top when
        /// vertical).
        case start
        /// Flush against trailing edge (right when horizontal, bottom when
        /// vertical).
        case end
        /// Keep prior viewport offset and pan minimum needed to reveal focus
        /// (#66).
        case follow
    }

    /// Axis along which columns/rows scroll.
    public enum Orientation: String, Sendable, Codable, CaseIterable {
        case horizontal
        case vertical
    }

    /// Fixed slot size along scroll axis.
    public var slotSize: ScrollSize = .auto
    /// Where the focused column rests in the viewport (#239).
    public var anchor: Anchor = .follow
    public var orientation: Orientation = .horizontal
    public var newWindowPlacement: SpawnPlacement = .afterFocused
    /// Whether focus wraps past row ends (#168).
    public var wrapFocus = false
    public var appBar = LayoutAppBar()
    /// Per-space overrides resolved via
    /// `TilingSettings.resolvedScrolling(for:)`.
    public var override: [SpaceID: ScrollingOverride] = [:]

    public init() {}

    /// True while scroll axis runs horizontally (#293).
    public var axisIsHorizontal: Bool {
        orientation == .horizontal
    }

    private enum CodingKeys: String, CodingKey {
        case slotSize = "slot_size"
        case anchor
        case orientation
        case newWindowPlacement = "new_window_placement"
        case wrapFocus = "wrap_focus"
        case appBar = "app_bar"
        case override
    }

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
