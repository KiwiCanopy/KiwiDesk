import Foundation

/// Per-space overrides of StackParams: optional mirror, nil
/// inherits (`StackOverrideTests`, #17). `newWindowPlacement` is
/// excluded — it has its own per-space override via
/// `new_window_placement_override`.
public struct StackOverride: Sendable, Equatable {
    public var masterCount: Int?
    public var masterRatio: Double?
    public var overflowStyle: StackParams.OverflowStyle?
    public var masterOrientation: StackParams.Orientation?
    public var stackPosition: StackParams.StackPosition?

    public init() {}

    /// Merges overrides onto global StackParams.
    public func resolved(onto global: StackParams) -> StackParams {
        var out = global
        if let masterCount { out.masterCount = masterCount }
        if let masterRatio { out.masterRatio = masterRatio }
        if let overflowStyle { out.overflowStyle = overflowStyle }
        if let masterOrientation {
            out.masterOrientation = masterOrientation
        }
        if let stackPosition { out.stackPosition = stackPosition }
        // Merged params hold no override map (see
        // ScrollingOverride).
        out.override = [:]
        return out
    }

    /// True when no field is set (drives sparse encoding).
    public var isEmpty: Bool {
        masterCount == nil && masterRatio == nil
            && overflowStyle == nil && masterOrientation == nil
            && stackPosition == nil
    }
}

extension StackOverride: Codable {
    enum CodingKeys: String, CodingKey {
        case masterCount = "master_count"
        case masterRatio = "master_ratio"
        case overflowStyle = "overflow_style"
        case masterOrientation = "master_orientation"
        case stackPosition = "stack_position"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        masterCount = try container.decodeIfPresent(
            Int.self,
            forKey: .masterCount
        )
        masterRatio = try container.decodeIfPresent(
            Double.self,
            forKey: .masterRatio
        )
        overflowStyle = try container.decodeIfPresent(
            StackParams.OverflowStyle.self,
            forKey: .overflowStyle
        )
        masterOrientation = try container.decodeIfPresent(
            StackParams.Orientation.self,
            forKey: .masterOrientation
        )
        stackPosition = try container.decodeIfPresent(
            StackParams.StackPosition.self,
            forKey: .stackPosition
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(
            masterCount,
            forKey: .masterCount
        )
        try container.encodeIfPresent(
            masterRatio,
            forKey: .masterRatio
        )
        try container.encodeIfPresent(
            overflowStyle,
            forKey: .overflowStyle
        )
        try container.encodeIfPresent(
            masterOrientation,
            forKey: .masterOrientation
        )
        try container.encodeIfPresent(
            stackPosition,
            forKey: .stackPosition
        )
    }
}
