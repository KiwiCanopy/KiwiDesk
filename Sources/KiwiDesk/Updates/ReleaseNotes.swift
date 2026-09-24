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

    let summary: String
    /// The "Before you update" paragraph, when the release has one.
    let heads: String?
    let sections: [Section]

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

    /// SF Symbol per group — one config, no hue (#1542 ruling).
    var symbol: String {
        switch self {
        case .new: return "sparkles"
        case .improved: return "arrow.up.circle"
        case .fixed: return "wrench.and.screwdriver"
        case .scripting: return "terminal"
        }
    }

    /// The symbol for a type this build does not know.
    static let otherSymbol = "circle.fill"
}
