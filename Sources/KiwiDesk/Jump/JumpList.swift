import Foundation
import KiwiDeskCore

/// The panel's list state over one opening's snapshot (#1875):
/// the query, the ranked results and the selection. Pure, so the
/// keys' rulings — preselection, the wrap, the result numbering —
/// are held without a panel.
struct JumpList {
    let snapshot: JumpSnapshot
    private(set) var query = ""
    private(set) var results: [JumpSearch.Match]
    /// Index into `results`; nil only while there are none.
    private(set) var selection: Int?
    /// The app strip's tile (#3135): 0 is All, `n` the snapshot's
    /// app `n − 1`, whose rows alone the list then shows.
    private(set) var tile = 0
    /// The apps holding a match for `query`; every app while it is
    /// empty. A tile outside it dims and takes no pick.
    private(set) var matchedApps: Set<pid_t>

    /// Results that take a ⌘ number.
    static let numbered = 9

    init(snapshot: JumpSnapshot) {
        self.snapshot = snapshot
        results = JumpSearch.matches(snapshot.entries, query: "")
        matchedApps = Set(snapshot.apps.map(\.pid))
        selection = results.isEmpty ? nil : 0
    }

    /// Re-ranks for `text` over every app — typing returns the
    /// strip to All (#3135); row 1 is preselected either way — with
    /// the focused window left out, an empty query's row 1 is the
    /// previous window, so opening and pressing Return goes back.
    mutating func setQuery(_ text: String) {
        guard text != query else { return }
        query = text
        tile = 0
        let all = JumpSearch.matches(snapshot.entries, query: text)
        matchedApps =
            text.isEmpty
            ? Set(snapshot.apps.map(\.pid)) : Set(all.map(\.entry.pid))
        results = all
        selection = results.isEmpty ? nil : 0
    }

    /// Moves the selection by `delta` rows, clamped at both ends;
    /// with `wrap`, one row past an end lands on the other (#2897).
    mutating func step(_ delta: Int, wrap: Bool = false) {
        guard let selection, !results.isEmpty else { return }
        self.selection = Self.stepped(
            selection,
            by: delta,
            count: results.count,
            wrap: wrap
        )
    }

    /// `index` moved by `delta` within `count`, clamped; with `wrap`
    /// a single step past an end lands on the other, a page never.
    static func stepped(
        _ index: Int,
        by delta: Int,
        count: Int,
        wrap: Bool
    ) -> Int {
        let next = index + delta
        if wrap, abs(delta) == 1, !(0..<count).contains(next) {
            return delta < 0 ? count - 1 : 0
        }
        return min(max(next, 0), count - 1)
    }

    /// Selects row `index` where one exists.
    mutating func select(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selection = index
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

    /// Where the Other apps section starts, nil without one: the
    /// first row of an app the lens on does not hold, which ranks
    /// after every member's (#2103 ruling 36). Its rows take no
    /// further header.
    var otherAppsStart: Int? {
        results.firstIndex { $0.entry.isOtherApp }
    }

    /// The rows the Minimized and Hidden headers divide: the lens's
    /// apps', or every row while no lens is on.
    private var tiered: ArraySlice<JumpSearch.Match> {
        results[..<(otherAppsStart ?? results.endIndex)]
    }

    /// Where the Hidden section starts, nil without one.
    var hiddenStart: Int? {
        tiered.firstIndex { $0.entry.isHiddenApp }
    }

    /// Where the Minimized section starts, nil without one: the
    /// first minimized window, which ranks after every open one.
    var minimizedStart: Int? {
        tiered.firstIndex {
            !$0.entry.isHiddenApp && $0.entry.status == .minimized
        }
    }

    /// Where the Pocket section starts, nil without one (#2446).
    var pocketStart: Int? {
        tiered.firstIndex { $0.entry.isPocketed }
    }

    /// The section header drawn above row `index`, if one starts
    /// there.
    func section(at index: Int) -> Section? {
        if index == minimizedStart { return .minimized }
        if index == hiddenStart { return .hidden }
        if index == pocketStart { return .pocket }
        if index == otherAppsStart { return .otherApps }
        return nil
    }

    /// How many section headers the list draws.
    var sectionCount: Int {
        [minimizedStart, hiddenStart, pocketStart, otherAppsStart]
            .compactMap { $0 }.count
    }

    enum Section { case minimized, hidden, pocket, otherApps }

}

/// The Windows side's app strip (#3135): All, then the snapshot's
/// apps most recently used first. A tile narrows the list to its
/// app's rows, in the list's own order, so its first row is the
/// app's most recent window; a query keeps covering every app.
extension JumpList {
    /// The app the strip is on; nil on All.
    var stripApp: JumpApp? {
        tile == 0 ? nil : snapshot.apps[tile - 1]
    }

    /// How many tiles the strip draws, All included.
    var tileCount: Int { snapshot.apps.count + 1 }

    /// Whether the strip shows (#3168): off All, or under a query,
    /// so ⌃⌥J opens on the list alone.
    var stripShown: Bool { tile != 0 || !query.isEmpty }

    /// The current window, drawn greyed at the top of All and of
    /// its app's tile (#3168); nil under a query, which never
    /// matches it, and where KiwiDesk tracks none.
    var yours: JumpEntry? {
        guard query.isEmpty, let yours = snapshot.yours,
            tile == 0 || stripApp?.pid == yours.pid
        else { return nil }
        return yours
    }

    /// The list's rows as drawn: the results, and the current
    /// window above them where it shows.
    var drawnRows: Int { results.count + (yours == nil ? 0 : 1) }

    /// Whether tile `index` holds a match for the query; All always.
    func tileMatches(_ index: Int) -> Bool {
        guard index > 0, snapshot.apps.indices.contains(index - 1) else {
            return index == 0
        }
        return matchedApps.contains(snapshot.apps[index - 1].pid)
    }

    /// How many windows the app has: its rows, a hidden app's row
    /// being none, and the current window where it is the app's.
    func windowCount(of app: JumpApp) -> Int {
        let listed = snapshot.entries.filter {
            $0.pid == app.pid && !$0.isHiddenApp
        }.count
        return listed + (snapshot.yours?.pid == app.pid ? 1 : 0)
    }

    /// Moves the strip by `delta` tiles, over the tiles with a
    /// match, wrapping on a fresh press only (#2897).
    mutating func stepTile(_ delta: Int, wrap: Bool) {
        let walkable = (0..<tileCount).filter(tileMatches)
        guard let at = walkable.firstIndex(of: tile) else { return }
        let next = Self.stepped(
            at,
            by: delta,
            count: walkable.count,
            wrap: wrap
        )
        pickTile(walkable[next])
    }

    /// Puts the strip on tile `index` where it holds a match; the
    /// list narrows to that app's matches, row 1 selected.
    mutating func pickTile(_ index: Int) {
        guard index != tile, tileMatches(index) else { return }
        tile = index
        let all = JumpSearch.matches(snapshot.entries, query: query)
        results =
            stripApp.map { app in
                all.filter { $0.entry.pid == app.pid }
            } ?? all
        selection = results.isEmpty ? nil : 0
    }

    /// Puts the strip on the app of the window used last — Core's
    /// `lastUsed`, else row 1 — and selects that window: the opener
    /// for the last app (#3135), so ↩ goes back.
    mutating func pickLastApp() {
        guard
            let target = snapshot.lastUsed ?? results.first?.entry.target,
            let entry = snapshot.entries.first(where: { $0.target == target }),
            let index = snapshot.apps.firstIndex(where: {
                $0.pid == entry.pid
            })
        else { return }
        pickTile(index + 1)
        if let row = results.firstIndex(where: { $0.entry.target == target }) {
            selection = row
        }
    }
}
