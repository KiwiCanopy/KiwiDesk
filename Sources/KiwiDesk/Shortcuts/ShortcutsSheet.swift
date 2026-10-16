import Foundation

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
            + shown.inactive.count + shown.apps.count + shown.custom.count
    }

    static func filtered(
        _ reference: ShortcutsReference,
        by needle: String
    ) -> ShortcutsReference {
        func keeps(_ row: ShortcutRow) -> Bool {
            matchRange(of: needle, in: row.label) != nil
        }
        // A folded row stays whole where every member matches, or
        // none does and its own label still matches; otherwise it
        // opens to the members that match (#2312).
        func shown(_ row: ShortcutRow) -> [ShortcutRow] {
            let hits = row.members.filter(keeps)
            if hits.isEmpty { return keeps(row) ? [row] : [] }
            return hits.count == row.members.count ? [row] : hits
        }
        var out = reference
        out.controls = reference.controls.compactMap { group in
            let rows = group.rows.flatMap(shown)
            return rows.isEmpty
                ? nil : ShortcutSubgroup(title: group.title, rows: rows)
        }
        out.inactive = reference.inactive.filter(keeps)
        out.apps = reference.apps.filter(keeps)
        out.custom = reference.custom.filter(keeps)
        return out
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
