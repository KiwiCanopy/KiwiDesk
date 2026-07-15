import Foundation

/// The stack layout's parameters, split from `LayoutParams`
/// for file size (AGENTS.md §2) when the #222 arrangement
/// fields joined the ratio/count/overflow trio.
public struct StackParams: Sendable, Equatable, Codable {
    /// What happens when a zone can't give every window
    /// `minWindowSize`.
    public enum OverflowStyle: String, Sendable, Codable {
        /// Only the windows that don't fit cascade at the
        /// bottom; the rest stay fully tiled.
        case cascadeOverflow = "cascade_overflow"
        /// The whole zone cascades.
        case cascadeAll = "cascade_all"
    }

    /// How a zone lines up its windows (#222). The overflow
    /// cascade is NOT affected: piles always offset downward
    /// so title bars stay visible (`OverlapStack`).
    public enum Orientation: String, Sendable, Codable {
        /// Windows stacked top-to-bottom (a column).
        case vertical
        /// Windows side by side (a row).
        case horizontal
    }

    /// Where the stack zone sits relative to the master
    /// (#222). Decides the split axis: `left`/`right` split
    /// the width, `top`/`bottom` split the height.
    public enum StackPosition: String, Sendable, Codable {
        case top
        case right
        case bottom
        case left

        /// True when the master/stack split divides the
        /// width — the single authority for the split axis,
        /// shared by the layout math and both resize paths.
        public var splitsHorizontally: Bool {
            self == .left || self == .right
        }

        /// The stack zone's lineup, derived — never a free
        /// knob (design decision on #222): a left/right zone
        /// is a tall strip, so it stacks vertically; a
        /// top/bottom zone is wide, so windows sit side by
        /// side. Any other combination degenerates into
        /// slivers.
        public var stackOrientation: Orientation {
            splitsHorizontally ? .vertical : .horizontal
        }
    }

    /// Windows 0..<masterCount form the master zone.
    public var masterCount: Int = 1
    /// The master zone's share of the split axis.
    public var masterRatio: Double = 0.6
    /// Zone overflow behavior (applies to both zones).
    public var overflowStyle: OverflowStyle = .cascadeOverflow
    /// How the master zone lines up its windows (#222). The
    /// stack zone has no such knob — its lineup derives from
    /// `stackPosition` (see `StackPosition.stackOrientation`).
    public var masterOrientation: Orientation = .vertical
    /// Where the stack zone sits (#222); `right` is the
    /// classic dwm arrangement (master left).
    public var stackPosition: StackPosition = .right
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
        case masterOrientation = "master_orientation"
        case stackPosition = "stack_position"
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
        masterOrientation =
            try container.decodeIfPresent(
                Orientation.self,
                forKey: .masterOrientation
            ) ?? .vertical
        stackPosition =
            try container.decodeIfPresent(
                StackPosition.self,
                forKey: .stackPosition
            ) ?? .right
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
            masterOrientation,
            forKey: .masterOrientation
        )
        try container.encode(
            stackPosition,
            forKey: .stackPosition
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
