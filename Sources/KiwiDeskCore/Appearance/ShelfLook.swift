import Foundation

/// Named sparse set of shelf STYLING settings, applied one-shot
/// like a palette and never a live link (#1684). Colours are not
/// its own: a look names a palette, so there is one colour
/// library (ruling 2026-09-27).
public struct ShelfLook: Sendable, Equatable, Codable {
    /// Display name. Bundled names are reserved; uniqueness among
    /// user looks is the store's.
    public var name: String
    /// The palette the look is drawn in, by NAME — resolved at
    /// apply time, so a missing one paints nothing.
    public var palette: String?
    /// Sparse map of styling path (`LookKeys`) to its value, as a
    /// `set_*` command would take it.
    public var style: [String: JSONValue]

    public init(
        name: String,
        palette: String?,
        style: [String: JSONValue]
    ) {
        self.name = name
        self.palette = palette
        self.style = style
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case palette
        case style
    }
}
