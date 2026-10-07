import Foundation

/// One version's notes as `scripts/appcast-sync` writes them into
/// the feed (#1542). The growth rules are packaging-and-release.md
/// ▸ the `kiwidesk:notes` paragraph: unknown keys are ignored, an
/// unknown section type is shown under its `title`, and an
/// unknown format or malformed document reads as nil.
struct ReleaseNotes: Decodable, Equatable {
    /// The item element's qualified name — Sparkle's key in
    /// `SUAppcastItem.propertiesDictionary`. Permanent from the
    /// first build that reads it; `ReleaseNotesFeedParityTests`
    /// holds it to the generator.
    static let element = "kiwidesk:notes"

    /// The `NOTES_FORMAT` values this window reads.
    static let knownFormats: Set<Int> = [1]

    struct Section: Decodable, Equatable {
        let type: String
        let title: String
        let items: [String]
    }

    /// One spotlight row (#2038): a signpost to a change whose
    /// record stays a bullet in its section. English, like the
    /// notes; `setting` is a `SettingKey.id`, `symbol` an SF
    /// Symbol name, both optional.
    struct SpotlightRow: Decodable, Equatable {
        let title: String
        let line: String
        var setting: String?
        var symbol: String?
    }

    let summary: String
    /// The "Before you update" paragraph, when the release has one.
    let heads: String?
    let sections: [Section]
    /// The spotlight rows, empty for a release told in prose. A
    /// malformed list reads as empty rather than costing the
    /// version its notes: the rows are optional growth.
    let spotlight: [SpotlightRow]

    private enum CodingKeys: String, CodingKey {
        case summary, heads, sections, spotlight
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        heads = try container.decodeIfPresent(String.self, forKey: .heads)
        sections = try container.decode([Section].self, forKey: .sections)
        spotlight =
            (try? container.decodeIfPresent(
                [SpotlightRow].self,
                forKey: .spotlight
            )) ?? []
    }

    private struct Format: Decodable {
        let format: Int
    }

    /// Nil for an absent element, an unknown format or a
    /// document that does not decode.
    static func decode(_ text: String?) -> ReleaseNotes? {
        guard let text else { return nil }
        let data = Data(text.utf8)
        let decoder = JSONDecoder()
        guard
            let format = try? decoder.decode(Format.self, from: data),
            knownFormats.contains(format.format)
        else { return nil }
        return try? decoder.decode(ReleaseNotes.self, from: data)
    }
}

/// A section type the window names in the reader's language; any
/// other type is drawn under the title the feed carries.
enum ReleaseNoteKind: String, CaseIterable {
    case new
    case improved
    case fixed
    case scripting
}
