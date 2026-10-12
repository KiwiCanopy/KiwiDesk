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
        selection = results.isEmpty ? nil : 0
    }

    /// Re-ranks for `text`; row 1 is preselected either way — with
    /// the focused window left out, an empty query's row 1 is the
    /// previous window, so opening and pressing Return goes back.
    mutating func setQuery(_ text: String) {
        guard text != query else { return }
        query = text
        results = JumpSearch.matches(snapshot.entries, query: text)
        selection = results.isEmpty ? nil : 0
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

    /// Where the Minimized section starts, nil without one: the
    /// first minimized window, which ranks after every open one.
    var minimizedStart: Int? {
        results.firstIndex {
            !$0.entry.isHiddenApp && $0.entry.status == .minimized
        }
    }

    /// The section header drawn above row `index`, if one starts
    /// there.
    func section(at index: Int) -> Section? {
        if index == minimizedStart { return .minimized }
        if index == hiddenStart { return .hidden }
        return nil
    }

    /// How many section headers the list draws.
    var sectionCount: Int {
        [minimizedStart, hiddenStart].compactMap { $0 }.count
    }

    enum Section { case minimized, hidden }

}
