import KiwiDeskCore

/// The panel's list state over one opening's snapshot (#1875):
/// the query, the ranked results and the selection. Pure, so the
/// keys' rulings — preselection, no wrap, the result numbering —
/// are held without a panel.
struct JumpList {
    let snapshot: JumpSnapshot
    private(set) var query = ""
    private(set) var results: [JumpSearch.Match]
    /// Index into `results`; nil only while there are none.
    private(set) var selection: Int?

    /// Results that take a ⌘ number.
    static let numbered = 9

    init(snapshot: JumpSnapshot) {
        self.snapshot = snapshot
        results = JumpSearch.matches(snapshot.entries, query: "")
        selection = Self.preselection(results.count, blank: true)
    }

    /// Re-ranks for `text`. An empty query preselects row 2, so
    /// opening and pressing Return goes back to the previous
    /// window; typing preselects row 1.
    mutating func setQuery(_ text: String) {
        guard text != query else { return }
        query = text
        results = JumpSearch.matches(snapshot.entries, query: text)
        selection = Self.preselection(
            results.count,
            blank: text.isEmpty
        )
    }

    /// Moves the selection by `delta` rows, clamped at both ends.
    mutating func step(_ delta: Int) {
        guard let selection, !results.isEmpty else { return }
        self.selection = min(
            max(selection + delta, 0),
            results.count - 1
        )
    }

    var selected: JumpSearch.Match? {
        selection.map { results[$0] }
    }

    /// The match a ⌘ digit picks — by result, never by scroll.
    func quick(_ index: Int) -> JumpSearch.Match? {
        guard index < Self.numbered, index < results.count else {
            return nil
        }
        return results[index]
    }

    /// The ⌘ number row `index` takes, nil from row 10 on. The
    /// numbering runs on across the Hidden header.
    static func number(ofRow index: Int) -> Int? {
        index < numbered ? index + 1 : nil
    }

    /// Where the Hidden section starts, nil without one.
    var hiddenStart: Int? {
        results.firstIndex { $0.entry.isHiddenApp }
    }

    private static func preselection(
        _ count: Int,
        blank: Bool
    ) -> Int? {
        guard count > 0 else { return nil }
        return blank && count > 1 ? 1 : 0
    }
}
