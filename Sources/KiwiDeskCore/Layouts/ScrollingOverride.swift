import Foundation

/// Per-space overrides of ScrollingParams (`ScrollingOverrideTests`, #17).
public struct ScrollingOverride: Sendable, Equatable {
    public var slotSize: ScrollSize?
    public var anchor: ScrollingParams.Anchor?
    public var orientation: ScrollingParams.Orientation?

    public init() {}

    /// Merges non-nil override fields onto global ScrollingParams.
    public func resolved(
        onto global: ScrollingParams
    ) -> ScrollingParams {
        var out = global
        if let slotSize { out.slotSize = slotSize }
        if let anchor { out.anchor = anchor }
        if let orientation { out.orientation = orientation }
        // The merged per-space params carry no override map of
        // their own — layout math never reads it, and it would
        // duplicate every space's overrides into each snapshot.
        out.override = [:]
        return out
    }

    /// True when no override field is set.
    public var isEmpty: Bool {
        slotSize == nil && anchor == nil && orientation == nil
    }
}

extension ScrollingOverride: Codable {
    enum CodingKeys: String, CodingKey {
        case slotSize = "slot_size"
        case anchor
        case orientation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        slotSize = try container.decodeIfPresent(
            ScrollSize.self,
            forKey: .slotSize
        )
        anchor = try container.decodeIfPresent(
            ScrollingParams.Anchor.self,
            forKey: .anchor
        )
        orientation = try container.decodeIfPresent(
            ScrollingParams.Orientation.self,
            forKey: .orientation
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(slotSize, forKey: .slotSize)
        try container.encodeIfPresent(anchor, forKey: .anchor)
        try container.encodeIfPresent(
            orientation,
            forKey: .orientation
        )
    }
}
