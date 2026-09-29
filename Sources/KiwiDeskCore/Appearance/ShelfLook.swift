import Foundation

/// Named shelf appearance — its STYLING and its COLOURS — applied
/// one-shot and never a live link (#1684). A look owns its
/// colours whole (#1752), so it reproduces its picture on any Mac
/// and whatever the palette library later holds; a palette is a
/// colour recipe painted into it.
public struct ShelfLook: Sendable, Equatable, Codable {
    /// Display name. Bundled names are reserved; uniqueness among
    /// user looks is the store's.
    public var name: String
    /// Sparse map of styling path (`LookKeys`) to its value, as a
    /// `set_*` command would take it.
    public var style: [String: JSONValue]
    /// Colour path (`ColorPaletteKeys`) to hex, every path — the
    /// shipped colours included, so applying a look leaves no
    /// earlier colour behind.
    public var colors: [String: String]

    public init(
        name: String,
        style: [String: JSONValue],
        colors: [String: String]
    ) {
        self.name = name
        self.style = style
        self.colors = colors
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case style
        case colors
    }
}
