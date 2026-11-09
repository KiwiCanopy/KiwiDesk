import Foundation
import KiwiDeskCore

/// The key panel's Shortcuts side (#2246): the reference read when
/// the side opens, and the typed query that narrows it. Read-only —
/// ↩ runs nothing. `reference` is nil where `init.lua` owns the
/// shortcuts.
struct ShortcutsSheet {
    let reference: ShortcutsReference?
    private(set) var query = ""

    init(reference: ShortcutsReference?) {
        self.reference = reference
    }

    mutating func setQuery(_ query: String) {
        self.query = query
    }

    /// The query with its outer whitespace dropped; empty shows the
    /// whole sheet.
    var needle: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    /// The reference narrowed to the rows whose name holds the
    /// query; a band or subgroup with none left is dropped, the
    /// rest keep their titles.
    var shown: ShortcutsReference? {
        guard let reference else { return nil }
        let needle = needle
        guard !needle.isEmpty else { return reference }
        return Self.filtered(reference, by: needle)
    }

    /// How many rows the query keeps.
    var matchCount: Int {
        guard let shown else { return 0 }
        return shown.controls.reduce(0) { $0 + $1.rows.count }
            + shown.inactive.count + shown.desktopAway.count
            + shown.apps.count + shown.custom.count
            + shown.groups.reduce(0) { $0 + $1.rows.count }
    }

    static func filtered(
        _ reference: ShortcutsReference,
        by needle: String
    ) -> ShortcutsReference {
        func keeps(_ row: ShortcutRow) -> Bool {
            matched(row, by: needle) != nil
        }
        // A folded row stays whole where every member matches, or
        // none does and its own label still matches; otherwise it
        // opens to the members that match (#2312).
        func shown(_ row: ShortcutRow) -> [ShortcutRow] {
            let hits = row.members.filter(keeps)
            if hits.isEmpty {
                return matched(row, by: needle).map { [$0] } ?? []
            }
            return hits.count == row.members.count ? [row] : hits
        }
        var out = reference
        func narrowed(_ groups: [ShortcutSubgroup]) -> [ShortcutSubgroup] {
            groups.compactMap { group in
                var group = group
                group.rows = group.rows.flatMap(shown)
                return group.rows.isEmpty ? nil : group
            }
        }
        out.controls = narrowed(reference.controls)
        out.groups = narrowed(reference.groups)
        out.inactive = reference.inactive.compactMap {
            matched($0, by: needle)
        }
        out.desktopAway = reference.desktopAway.compactMap {
            matched($0, by: needle)
        }
        out.apps = reference.apps.compactMap { matched($0, by: needle) }
        out.custom = reference.custom.compactMap { matched($0, by: needle) }
        return out
    }

    /// `row` as the query keeps it: by its name, or by a name along
    /// its key sequence's path, which its row then names
    /// (#1871), so a hit never matches text the row does not draw;
    /// nil where neither holds the query.
    static func matched(_ row: ShortcutRow, by needle: String) -> ShortcutRow?
    {
        if matchRange(of: needle, in: row.label) != nil { return row }
        guard
            let name = row.pathNames.first(where: {
                matchRange(of: needle, in: $0) != nil
            })
        else { return nil }
        var row = row
        row.matchedPathName = name
        return row
    }

    /// Where `needle` sits in `label`, ignoring case and
    /// diacritics; the row draws that range bold.
    static func matchRange(
        of needle: String,
        in label: String
    ) -> Range<String.Index>? {
        guard !needle.isEmpty else { return nil }
        return label.range(
            of: needle,
            options: [.caseInsensitive, .diacriticInsensitive]
        )
    }
}
