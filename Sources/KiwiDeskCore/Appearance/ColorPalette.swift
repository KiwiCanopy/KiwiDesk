import Foundation

/// Named sparse color recipe applied one-shot to profile colors (#375).
public struct ColorPalette: Sendable, Equatable, Codable {
    /// Display name of the palette.
    public var name: String
    /// Sparse map of color path (`ColorPaletteKeys`) to hex string.
    public var colors: [String: String]

    public init(name: String, colors: [String: String]) {
        self.name = name
        self.colors = colors
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case colors
    }
}
