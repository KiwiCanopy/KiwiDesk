import Foundation

/// A named color recipe (#375): a sparse map of color paths to hex
/// values, applied **once** to overwrite a profile's colors — never
/// a live link (the `copyAppearance` model). A key the palette
/// omits leaves that color untouched, so a palette can be as
/// focused or as complete as it likes.
///
/// A palette is not a Profile: a Profile is the persistent,
/// addressable configuration (tiling, layout, sparse behavior
/// overrides) that owns the colors *after* a palette paints them.
public struct ColorPalette: Sendable, Equatable, Codable {
    /// Display name. Bundled names are reserved (a user palette may
    /// not shadow one); uniqueness among user palettes is enforced
    /// by the store, not here.
    public var name: String
    /// Color path (`ColorPaletteKeys`) → hex (`#RRGGBB[AA]`),
    /// sparse. Invalid hexes and unknown paths are skipped on
    /// apply, never fatal.
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
