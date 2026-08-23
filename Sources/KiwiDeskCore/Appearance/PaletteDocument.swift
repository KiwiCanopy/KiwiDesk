import Foundation

/// The envelope for `palettes.json` (#939): format versioning
/// plus the list of user palettes.
///
/// The format integer is homed HERE, on the file's ROOT type —
/// the pattern the siblings set (`Profile`, `GuiConfig`,
/// `SetupBundle`) — never on `ColorPalette`, which also travels
/// inside `SetupBundle`, where the bundle's own format governs
/// (#945 review).
struct PaletteDocument: Codable {
    /// Format version of the palettes.json schema (#939).
    /// Format 0 = unversioned legacy bare array.
    static let currentFormat = 1

    /// The format the file actually carried. Normalized to
    /// `currentFormat` only by a WRITE, never by the decoder: a
    /// decoder that normalizes makes every format assertion
    /// read the decoder back instead of the file, which is how
    /// the save path's stamp went unguarded (#945 review,
    /// proven by mutation).
    var format: Int
    var palettes: [ColorPalette]

    enum CodingKeys: String, CodingKey {
        case format
        case palettes
    }

    init(
        format: Int = PaletteDocument.currentFormat,
        palettes: [ColorPalette]
    ) {
        self.format = format
        self.palettes = palettes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let decodedFormat =
            try container.decodeIfPresent(
                Int.self,
                forKey: .format
            ) ?? 0
        guard decodedFormat <= Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription:
                    "palette format \(decodedFormat) is newer "
                    + "than supported \(Self.currentFormat)"
            )
        }
        format = decodedFormat
        palettes =
            try container.decodeIfPresent(
                [ColorPalette].self,
                forKey: .palettes
            ) ?? []
    }
}
