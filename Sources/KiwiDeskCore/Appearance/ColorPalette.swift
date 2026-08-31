import Foundation

/// Named sparse color recipe applied one-shot to profile colors (#375).
public struct ColorPalette: Sendable, Equatable, Codable {
    /// Display name. Bundled names are reserved (a user palette
    /// may not shadow one); uniqueness among user palettes is
    /// enforced by the store, not here.
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
