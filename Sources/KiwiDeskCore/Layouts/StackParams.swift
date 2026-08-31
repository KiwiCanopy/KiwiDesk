import Foundation

/// Parameters for the stack/master-stack layout engine (#222).
public struct StackParams: Sendable, Equatable, Codable {
    /// Overflow behavior when windows exceed `minWindowSize`.
    public enum OverflowStyle: String, Sendable, Codable, CaseIterable {
        case cascadeOverflow = "cascade_overflow"
        case cascadeAll = "cascade_all"
    }

    /// Linear orientation within a zone (`OverlapStack`, #222).
    public enum Orientation: String, Sendable, Codable, CaseIterable {
        case vertical
        case horizontal
    }

    /// Position of stack zone relative to master zone (#222).
    public enum StackPosition: String, Sendable, Codable, CaseIterable {
        case top
        case right
        case bottom
        case left

        /// True when the master/stack split divides width.
        public var splitsHorizontally: Bool {
            self == .left || self == .right
        }

        /// Inferred orientation for the stack zone — derived,
        /// never a free knob (#222): any other combination
        /// degenerates into slivers.
        public var stackOrientation: Orientation {
            splitsHorizontally ? .vertical : .horizontal
        }
    }

    /// Number of windows in the master zone.
    public var masterCount: Int = 1
    /// Master zone share of split axis.
    public var masterRatio: Double = 0.6
    /// Overflow behavior applying to both zones.
    public var overflowStyle: OverflowStyle = .cascadeOverflow
    /// Master zone layout orientation (#222).
    public var masterOrientation: Orientation = .horizontal
    /// Position of stack zone (#222).
    public var stackPosition: StackPosition = .right
    /// Spawn placement rule for incoming windows.
    public var newWindowPlacement: SpawnPlacement = .first
    /// Per-space overrides (`TilingSettings.resolvedStack(for:)`).
    public var override: [SpaceID: StackOverride] = [:]

    public init() {}

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
            ) ?? .horizontal
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

    /// Encodes stack parameters keeping sparse override map structure.
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
