import Foundation

/// One drag marker's switch (`drag.ghost`, `drag.drop_zone`). Its
/// look is fixed: the drop zone an untinted frosted plate, the ghost
/// a two-tone outline (#2797, `DragMarkerView`); the corners are
/// every window outline's, `TilingSettings.windowStroke` (#1742).
public struct DragVisual: Sendable, Equatable, Encodable {
    public var enabled: Bool

    /// The ghost, off for a fresh setup (#2797); a saved profile
    /// keeps the `enabled` it stored, since the struct encodes whole.
    public static let ghostDefault = DragVisual(enabled: false)

    /// The drop zone, on.
    public static let dropZoneDefault = DragVisual(enabled: true)

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    /// Serialization coding keys.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
    }

    /// Decodes the switch over `defaults` when absent.
    public init(
        from decoder: Decoder,
        defaults: DragVisual
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? defaults.enabled
    }
}
