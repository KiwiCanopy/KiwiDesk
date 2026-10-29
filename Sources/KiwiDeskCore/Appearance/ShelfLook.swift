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
    /// Who made it, kept from an imported look (#1740); nil for the
    /// user's own and a bundled one.
    public var author: String?
    /// The look it started from, while the credit rule keeps it.
    public var basedOn: LookCredit?
    /// The gallery id it was installed under (#1740), which a look
    /// started from it credits; nil for any other look.
    public var galleryID: String?

    public init(
        name: String,
        style: [String: JSONValue],
        colors: [String: String],
        author: String? = nil,
        basedOn: LookCredit? = nil,
        galleryID: String? = nil
    ) {
        self.name = name
        self.style = style
        self.colors = colors
        self.author = author
        self.basedOn = basedOn
        self.galleryID = galleryID
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case style
        case colors
        case author
        case basedOn = "based_on"
        case galleryID = "gallery_id"
    }
}

extension ShelfLook {
    /// This look without its motion (#2176): what the tour's paint
    /// reaches, which never changes how fast things move.
    public var stylingOnly: ShelfLook {
        let styling = Set(LookKeys.styling)
        return ShelfLook(
            name: name,
            style: style.filter { styling.contains($0.key) },
            colors: colors,
            author: author,
            basedOn: basedOn,
            galleryID: galleryID
        )
    }

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
            colors: ColorPalette(name: "", colors: known).paintedColors,
            author: author,
            basedOn: basedOn,
            galleryID: galleryID
        )
    }

    /// This look with its credit left out: the body an exported
    /// file carries under `look`, its credit beside it. The gallery
    /// id stays behind: it is this Mac's record of the install.
    var uncredited: ShelfLook {
        var body = self
        body.author = nil
        body.basedOn = nil
        body.galleryID = nil
        return body
    }
}
