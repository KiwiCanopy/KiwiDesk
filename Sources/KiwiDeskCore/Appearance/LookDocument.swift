import Foundation

/// Envelope for looks.json with its schema format (#1684). The
/// format lives on the file's ROOT type, never on `ShelfLook`,
/// which also travels inside `SetupBundle` under the bundle's own
/// format — the palette library's shape (#939, #945).
struct LookDocument: Codable {
    /// Format version of the looks.json schema. 2: a look owns
    /// its colours (#1752), carried by `LookColorCarry` rather than
    /// a `ConfigMigration` step.
    static let currentFormat = 2

    /// The format a byte-level step may stamp: the one below the
    /// carry, which alone writes `currentFormat` — a blind stamp
    /// would end the crossing with no colours.
    static let stampFloor = 1

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
/// needs. Bare, like the palette sidecar — a breaking `ShelfLook`
/// change must rule this file deliberately; a file from before
/// #1752 is read by `LookColorCarry.importedLegacy`.
public struct LookExport: Codable, Sendable, Equatable {
    public var look: ShelfLook

    public init(look: ShelfLook) {
        self.look = look
    }

    private enum CodingKeys: String, CodingKey {
        case look
    }
}
