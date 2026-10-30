import Foundation

/// Envelope for looks.json with its schema format (#1684). The
/// format lives on the file's ROOT type, never on `ShelfLook`,
/// which also travels inside `SetupBundle` under the bundle's own
/// format — the palette library's shape (#939, #945).
struct LookDocument: Codable {
    /// Format version of the looks.json schema: 2 since a look's
    /// `animations.on_shelf` / `shelf_duration` paths became
    /// `on_expand` / `expand_duration` (owner ruling, 2026-10-21), 3
    /// since the drag markers' palette paths retired (#2797).
    static let currentFormat = 3

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// Decoded format version preserved without normalization.
    var format: Int
    var looks: [ShelfLook]

    enum CodingKeys: String, CodingKey {
        case format
        case looks
    }

    init(
        format: Int = LookDocument.currentFormat,
        looks: [ShelfLook]
    ) {
        self.format = format
        self.looks = looks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let decodedFormat =
            try container.decodeIfPresent(Int.self, forKey: .format)
            ?? 0
        guard decodedFormat <= Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription:
                    "look format \(decodedFormat) is newer "
                    + "than supported \(Self.currentFormat)"
            )
        }
        format = decodedFormat
        looks =
            try container.decodeIfPresent(
                [ShelfLook].self,
                forKey: .looks
            ) ?? []
    }
}

/// An exported look (#1684): the look alone, which owns its
/// colours (#1752), so the file carries everything another Mac
/// needs, with the format it was written in and its credit (#1740).
/// A file without `format` is an older build's and reads as format
/// 0; the look body never carries the credit, which sits beside it.
public struct LookExport: Codable, Sendable, Equatable {
    public var format: Int
    public var author: String?
    public var basedOn: LookCredit?
    public var look: ShelfLook

    /// Splits the credit `look` carries out beside its body.
    public init(look: ShelfLook) {
        format = LookDocument.currentFormat
        author = look.author
        basedOn = look.basedOn
        self.look = look.uncredited
    }

    /// The look with its credit put back on it. A gallery id inside
    /// the body is dropped: only a link's install sets one (#1740).
    public var credited: ShelfLook {
        var out = look
        out.author = author
        out.basedOn = basedOn
        out.galleryID = nil
        return out
    }

    private enum CodingKeys: String, CodingKey {
        case format
        case author
        case basedOn = "based_on"
        case look
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format =
            try container.decodeIfPresent(Int.self, forKey: .format) ?? 0
        author = try container.decodeIfPresent(String.self, forKey: .author)
        basedOn = try container.decodeIfPresent(
            LookCredit.self,
            forKey: .basedOn
        )
        look = try container.decode(ShelfLook.self, forKey: .look)
    }
}
