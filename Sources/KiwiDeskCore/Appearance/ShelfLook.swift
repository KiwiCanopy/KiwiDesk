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

extension ShelfLook {
    /// A stored look made fit for use (#1752): styling keys outside
    /// `LookKeys` and colours outside `ColorPaletteKeys` dropped,
    /// then the colours completed over the shipped ones, so a
    /// colour path added since the look was saved never leaves an
    /// earlier colour behind when it is applied. A reader that
    /// applies, draws or copies a stored look takes this door; a
    /// rewrite of the store and a backup's export stay raw, so a
    /// newer build's keys survive them (`LookStoreTests`).
    public var admitted: ShelfLook {
        let style = Set(LookKeys.all)
        let colors = Set(ColorPaletteKeys.all)
        let known = self.colors.filter { colors.contains($0.key) }
        return ShelfLook(
            name: name,
            style: self.style.filter { style.contains($0.key) },
            colors: ColorPalette(name: "", colors: known).paintedColors
        )
    }
}
