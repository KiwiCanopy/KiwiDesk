import Foundation

/// Floating window mark and badge style settings (#429).
public struct FloatingStyle: Sendable, Equatable {
    /// Floating window SF Symbol name (`StickyStyle.symbolName`, #793).
    public static let symbolName = "macwindow.on.rectangle"

    /// Whether a window set floating wears the on-window mark
    /// (#1799) — the flag, never `EffectiveFloat`.
    public var mark = true

    /// Floating badge tint hex string; empty = automatic
    /// (`NSColor.mark`, #429).
    public var color = ""

    public init() {}
}

extension FloatingStyle: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case mark
        case color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        mark =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .mark
            ) ?? defaults.mark
        color =
            try container.decodeIfPresent(
                String.self,
                forKey: .color
            ) ?? defaults.color
    }
}
