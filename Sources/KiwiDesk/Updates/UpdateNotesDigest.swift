import Foundation

/// Every change between the installed version and the offered one,
/// merged by section type (#1542 ▸ "Everything since your
/// version"). Pure, so `UpdateNotesDigestTests` pins each rule
/// without Sparkle.
struct UpdateNotesDigest: Equatable {
    /// One feed item's version and its raw `kiwidesk:notes` text.
    struct Source: Equatable {
        let version: String
        let notes: String?
    }

    struct Entry: Equatable {
        let text: String
        let version: String
    }

    struct Group: Equatable, Identifiable {
        let type: String
        /// The feed's title — drawn only for a type the window
        /// does not know.
        let title: String
        let entries: [Entry]
        var id: String { type }
        var kind: ReleaseNoteKind? { ReleaseNoteKind(rawValue: type) }
    }

    struct Caution: Equatable {
        let version: String
        let text: String
    }

    /// The offered version's summary, for the Highlights panel.
    let summary: String
    /// Every merged version's "Before you update", newest first.
    let cautions: [Caution]
    let groups: [Group]
    /// Readable versions merged in, newest first.
    let versions: [String]
    /// Skipped versions whose notes could not be read — dropped
    /// from the groups and pointed at their full release notes.
    let unreadable: [String]

    /// Whether entries carry their version label: only a view
    /// spanning more than one version needs it.
    var spansVersions: Bool { versions.count > 1 }

    var total: Int { groups.reduce(0) { $0 + $1.entries.count } }

    /// Merges every source newer than `installed` up to `offered`.
    /// Nil when the offered version's own notes cannot be read —
    /// the window then falls back to the notes link alone.
    static func make(
        sources: [Source],
        installed: String,
        offered: String,
        compare: (String, String) -> ComparisonResult
    ) -> UpdateNotesDigest? {
        var seen = Set<String>()
        let inRange =
            sources
            .filter {
                compare($0.version, installed) == .orderedDescending
                    && compare($0.version, offered) != .orderedDescending
            }
            .filter { seen.insert($0.version).inserted }
            .sorted {
                compare($0.version, $1.version) == .orderedDescending
            }
        guard
            let newest = inRange.first,
            compare(newest.version, offered) == .orderedSame,
            let offeredNotes = ReleaseNotes.decode(newest.notes)
        else { return nil }
        var readable: [(String, ReleaseNotes)] = []
        var unreadable: [String] = []
        for source in inRange {
            if source.version == newest.version {
                readable.append((source.version, offeredNotes))
            } else if let notes = ReleaseNotes.decode(source.notes) {
                readable.append((source.version, notes))
            } else {
                unreadable.append(source.version)
            }
        }
        return UpdateNotesDigest(
            summary: offeredNotes.summary,
            cautions: readable.compactMap { version, notes in
                notes.heads.map { Caution(version: version, text: $0) }
            },
            groups: merged(readable),
            versions: readable.map(\.0),
            unreadable: unreadable
        )
    }

    /// Known types in their fixed order, unknown ones in the order
    /// first met, Lua & CLI always last.
    private static func merged(
        _ readable: [(String, ReleaseNotes)]
    ) -> [Group] {
        var order: [String] = []
        var titles: [String: String] = [:]
        var entries: [String: [Entry]] = [:]
        for (version, notes) in readable {
            for section in notes.sections where !section.items.isEmpty {
                if entries[section.type] == nil {
                    order.append(section.type)
                    titles[section.type] = section.title
                }
                entries[section.type, default: []] += section.items.map {
                    Entry(text: $0, version: version)
                }
            }
        }
        func rank(_ type: String) -> Int {
            switch ReleaseNoteKind(rawValue: type) {
            case .new: return 0
            case .improved: return 1
            case .fixed: return 2
            case .scripting: return 4
            case nil: return 3
            }
        }
        return
            order
            .enumerated()
            .sorted {
                (rank($0.element), $0.offset)
                    < (rank($1.element), $1.offset)
            }
            .map {
                Group(
                    type: $0.element,
                    title: titles[$0.element] ?? $0.element,
                    entries: entries[$0.element] ?? []
                )
            }
    }
}

/// Which groups start open, and how many entries an open group
/// shows before "Show more" (#1542 ruling).
enum UpdateNotesDisclosure {
    /// An open group shows up to this many entries…
    static let capacity = 5
    /// …otherwise this many plus "Show more · N".
    static let withMarker = 4

    /// The first group opens unless it is Lua & CLI, which always
    /// starts collapsed; the rest start collapsed.
    static func initiallyOpen(
        _ groups: [UpdateNotesDigest.Group]
    ) -> Set<String> {
        guard let first = groups.first, first.kind != .scripting
        else { return [] }
        return [first.id]
    }

    static func shown(of count: Int, expanded: Bool) -> Int {
        expanded
            ? count
            : OverflowSplit.shown(
                of: count,
                fitting: capacity,
                withMarker: withMarker
            )
    }
}
