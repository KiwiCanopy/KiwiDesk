import Foundation

/// The words inside the notes' cards (#1849): English, like the
/// notes they frame, while the strip, the title and the buttons
/// around them speak the user's language. One home, so a card
/// cannot mix the two.
enum UpdateNotesEnglish {
    /// Dates inside a card read as the notes do.
    static let locale = Locale(identifier: "en_US")
    static let highlights = "Highlights"
    static let beforeYouUpdate = "Before you update"
    static let goodToKnow = "Good to know"
    static let nextOnMyList = "Next on my list"
    static let discord = "Follow along and share ideas on Discord"
    static let support = "Like my work? Support KiwiDesk on Ko-fi"
    static let noNotes = "This version's notes are online."

    static func asOf(_ day: String) -> String { "As of \(day)" }

    /// The version after an entry, in brackets.
    static func entryVersion(_ version: String) -> String {
        " (\(version))"
    }

    static func name(_ group: UpdateNotesDigest.Group) -> String {
        switch group.kind {
        case .new: return "New"
        case .improved: return "Improved"
        case .fixed: return "Fixed"
        case .scripting: return "Lua & CLI"
        case nil: return group.title
        }
    }

    /// "Name · N", the card's heading.
    static func counted(_ group: UpdateNotesDigest.Group) -> String {
        "\(name(group)) · \(group.entries.count)"
    }
}
