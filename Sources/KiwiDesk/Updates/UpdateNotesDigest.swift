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

    /// A spotlight row with the version it came from (#2038).
    struct SpotlightEntry: Equatable {
        let row: ReleaseNotes.SpotlightRow
        let version: String
    }

    /// The offered version's summary, for the Highlights panel —
    /// its one intro sentence while `spotlight` has rows.
    let summary: String
    /// The Highlights rows, newest first, at most
    /// `spotlightCap`; empty draws the summary as prose.
    var spotlight: [SpotlightEntry] = []
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

    /// The group a tab opens.
    func group(_ id: String) -> Group? {
        groups.first { $0.id == id }
    }

    /// Merges every source newer than `installed` up to `offered`.
    /// Nil when the offered version's own notes cannot be read —
    /// the window then falls back to the notes link alone.
    /// `installed` nil is a 1.x upgrade whose start was never
    /// recorded: every version up to the offer, and the untyped
    /// 1.x releases dropped silently rather than each linked.
    static func make(
        sources: [Source],
        installed: String?,
        offered: String,
        compare: (String, String) -> ComparisonResult
    ) -> UpdateNotesDigest? {
        var seen = Set<String>()
        let inRange =
            sources
            .filter { source in
                let newer = installed.map {
                    compare(source.version, $0) == .orderedDescending
                }
                return (newer ?? true)
                    && compare(source.version, offered)
                        != .orderedDescending
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
            } else if installed != nil {
                unreadable.append(source.version)
            }
        }
        return UpdateNotesDigest(
            summary: offeredNotes.summary,
            spotlight: spotlight(readable),
            cautions: readable.compactMap { version, notes in
                notes.heads.map { Caution(version: version, text: $0) }
            },
            groups: merged(readable),
            versions: readable.map(\.0),
            unreadable: unreadable
        )
    }

    /// The most rows the Highlights tab draws (#2038).
    static let spotlightCap = 4

    /// Which rows the Highlights tab draws, newest first — the
    /// one home of the mixed-version rule (#2038 ruling ▸ rows
    /// win): rows when any covered version has them, unless the
    /// newest is a minor or major with none, whose prose then
    /// stands alone. The intro is always the newest version's
    /// summary — its intro sentence, or a patch's capped prose.
    /// Capped by trimming the oldest version's rows first.
    static func spotlight(
        _ readable: [(String, ReleaseNotes)]
    ) -> [SpotlightEntry] {
        guard let newest = readable.first,
            !newest.1.spotlight.isEmpty || isPatch(newest.0)
        else { return [] }
        let merged = readable.flatMap { version, notes in
            notes.spotlight.map {
                SpotlightEntry(row: $0, version: version)
            }
        }
        return Array(merged.prefix(spotlightCap))
    }

    /// `x.y.z` with z > 0, read off the leading digits so a
    /// suffix does not hide it.
    static func isPatch(_ version: String) -> Bool {
        let parts = version.split(separator: ".")
        guard parts.count >= 3 else { return false }
        return (Int(parts[2].prefix { $0.isNumber }) ?? 0) > 0
    }

    /// The version a row is tagged with: only a row older than
    /// the newest covered version carries one (#2038 ruling).
    func tag(_ entry: SpotlightEntry) -> String? {
        entry.version == versions.first ? nil : entry.version
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

/// One tab of the notes (#1666 ruling): Highlights, a type's
/// changes, then "Next on my list" (#1849).
enum UpdateNotesTab: Hashable {
    case highlights
    case group(String)
    case next
}

/// Which tabs exist and which one opens (#1666 ruling).
enum UpdateNotesTabs {
    /// Highlights, then one per non-empty group in digest order —
    /// a tab with nothing in it promises nothing — then Next while
    /// there is a list. Without a digest Highlights stays, saying
    /// the notes are online.
    static func tabs(
        _ digest: UpdateNotesDigest?,
        next: Bool = false
    ) -> [UpdateNotesTab] {
        [.highlights]
            + (digest?.groups ?? []).filter { !$0.entries.isEmpty }.map {
                .group($0.id)
            }
            + (next ? [.next] : [])
    }

    /// No strip when Highlights is the only tab.
    static func showsStrip(
        _ digest: UpdateNotesDigest?,
        next: Bool = false
    ) -> Bool {
        tabs(digest, next: next).count > 1
    }

    /// Highlights wherever there is an update: the "Before you
    /// update" cautions live there and must be seen before Install.
    static let initial = UpdateNotesTab.highlights

    /// With no update the list is the news, so Next opens (#1849).
    static func opening(upToDate: Bool, next: Bool) -> UpdateNotesTab {
        upToDate && next ? .next : initial
    }
}
