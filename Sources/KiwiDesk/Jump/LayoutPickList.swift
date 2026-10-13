import Foundation
import KiwiDeskCore

/// The Layouts scope's tiles (#2229): every layout in
/// `LayoutMode.allCases` order — the Layout menu's, and the ⌘
/// digits' — a typed filter and the selection. Pure, so the
/// filter and the keys are testable without a panel.
struct LayoutPickList: Equatable {
    let state: LayoutPickerState
    let modes: [LayoutMode] = LayoutMode.allCases
    /// Each mode's name as drawn, the filter's haystack.
    let names: [LayoutMode: String]
    private(set) var query = ""
    /// The selected tile's index into `modes`; nil while the
    /// query matches nothing.
    private(set) var selection: Int?

    init(state: LayoutPickerState, names: [LayoutMode: String]) {
        self.state = state
        self.names = names
        selection = modes.firstIndex(of: state.live)
    }

    var selected: LayoutMode? { selection.map { modes[$0] } }

    /// The tiles the query matches: by prefix, then by substring;
    /// every tile while the query is empty.
    var matches: [Int] {
        let typed = query.trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !typed.isEmpty else { return Array(modes.indices) }
        let lowered = modes.map { (names[$0] ?? $0.rawValue).lowercased() }
        let prefix = modes.indices.filter { lowered[$0].hasPrefix(typed) }
        let inner = modes.indices.filter {
            !lowered[$0].hasPrefix(typed) && lowered[$0].contains(typed)
        }
        return prefix + inner
    }

    func isDimmed(_ index: Int) -> Bool { !matches.contains(index) }

    /// A new query selects its first match — the live layout
    /// again once it is cleared.
    mutating func setQuery(_ query: String) {
        self.query = query
        selection =
            query.isEmpty
            ? modes.firstIndex(of: state.live)
            : matches.first
    }

    /// ← / →: the next matching tile in drawn order, never
    /// wrapping.
    mutating func step(_ delta: Int) {
        let order = matches.sorted()
        guard let current = selection,
            let at = order.firstIndex(of: current)
        else {
            selection = order.first
            return
        }
        let next = min(max(at + delta, 0), order.count - 1)
        selection = order[next]
    }

    /// Selects `mode` where the query still matches it.
    mutating func select(_ mode: LayoutMode) {
        guard let index = modes.firstIndex(of: mode),
            matches.contains(index)
        else { return }
        selection = index
    }

    /// ⌘1–7: the tile at that position, whatever the filter.
    func quick(_ index: Int) -> LayoutMode? {
        modes.indices.contains(index) ? modes[index] : nil
    }
}
