import Foundation
import KiwiDeskCore

/// KiwiHub's View side (#2309): the Layout, Profile and KiwiVision
/// lines, a typed filter over all three and the one selection.
/// Pure, so the filter and the keys are testable without a panel.
struct ViewPickList: Equatable {
    /// The lines, in drawn order.
    enum Line: Int, CaseIterable, Comparable, Sendable {
        case layout, profile, vision

        static func < (lhs: Line, rhs: Line) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// What an item applies.
    enum Pick: Hashable, Sendable {
        case layout(LayoutMode)
        case profile(String)
        /// KiwiVision off, or on around the focused window.
        case vision(Bool)
    }

    struct Item: Equatable, Identifiable {
        let pick: Pick
        /// The name as drawn, the filter's first spelling.
        let name: String
        /// Further spellings the filter reads, such as a config's
        /// own name a native script cannot be typed as.
        var spellings: [String] = []
        var isCurrent = false
        /// Why the item cannot be applied; nil where it can.
        var refusal: String?
        /// The item's own shortcut, drawn after its name.
        var chord: String?

        var id: Pick { pick }
        var isApplicable: Bool { refusal == nil }
    }

    struct Position: Equatable {
        let line: Line
        let index: Int
    }

    /// The Space the Layout line acts on; nil where there is none.
    let layout: LayoutPickerState?
    /// Each line's items; a line with no entry is not drawn.
    let items: [Line: [Item]]
    private(set) var query = ""
    /// The selected item; nil while the query matches nothing.
    private(set) var selection: Position?

    init(layout: LayoutPickerState?, items: [Line: [Item]]) {
        self.layout = layout
        self.items = items.filter { !$0.value.isEmpty }
        selection = nil
        selection = resting(on: lines.first ?? .layout)
    }

    /// The drawn lines, in order.
    var lines: [Line] { Line.allCases.filter { items[$0] != nil } }

    func items(_ line: Line) -> [Item] { items[line] ?? [] }

    var selected: Item? {
        selection.map { items($0.line)[$0.index] }
    }

    /// The items of `line` the query matches, in drawn order:
    /// every item while the query is empty.
    func matches(_ line: Line) -> [Int] {
        let typed = query.trimmingCharacters(in: .whitespaces)
            .lowercased()
        let all = items(line)
        guard !typed.isEmpty else { return Array(all.indices) }
        return all.indices.filter { index in
            ([all[index].name] + all[index].spellings).contains {
                $0.lowercased().contains(typed)
            }
        }
    }

    func isDimmed(_ line: Line, _ index: Int) -> Bool {
        !matches(line).contains(index)
    }

    /// The line's ⌘ number for the item, counted among the
    /// matches; nil past nine or for an item the query dims.
    func number(_ line: Line, _ index: Int) -> Int? {
        guard let at = matches(line).firstIndex(of: index), at < 9
        else { return nil }
        return at + 1
    }

    /// A new query selects its first match on the selection's
    /// line, else on the first line with one; a cleared query
    /// rests on that line's current item again.
    mutating func setQuery(_ query: String) {
        let line = selection?.line ?? lines.first ?? .layout
        self.query = query
        guard !query.isEmpty else {
            selection = resting(on: line)
            return
        }
        let order = [line] + lines.filter { $0 != line }
        let found = order.first { firstMatch($0) != nil }
        selection = found.flatMap { candidate in
            firstMatch(candidate).map {
                Position(line: candidate, index: $0)
            }
        }
    }

    /// The line's first match by prefix, else by substring.
    private func firstMatch(_ line: Line) -> Int? {
        let typed = query.trimmingCharacters(in: .whitespaces)
            .lowercased()
        let found = matches(line)
        let all = items(line)
        return found.first { index in
            ([all[index].name] + all[index].spellings).contains {
                $0.lowercased().hasPrefix(typed)
            }
        } ?? found.first
    }

    /// ← / →: the next matching item on the line, never wrapping.
    mutating func step(_ delta: Int) {
        guard let current = selection else { return }
        let order = matches(current.line)
        guard let at = order.firstIndex(of: current.index) else {
            return
        }
        let next = min(max(at + delta, 0), order.count - 1)
        selection = Position(line: current.line, index: order[next])
    }

    /// ↑ / ↓: the next line with a match, keeping the position
    /// along the line, clamped to a shorter one (#2309 ruling 11).
    mutating func moveLine(_ delta: Int) {
        guard let current = selection else { return }
        let reachable = lines.filter { !matches($0).isEmpty }
        guard let at = reachable.firstIndex(of: current.line) else {
            return
        }
        let next = at + delta
        guard reachable.indices.contains(next) else { return }
        let column = matches(current.line).firstIndex(of: current.index)
        let target = matches(reachable[next])
        let index = target[min(column ?? 0, target.count - 1)]
        selection = Position(line: reachable[next], index: index)
    }

    /// Selects `pick` where the query still matches it.
    mutating func select(_ pick: Pick) {
        for line in lines {
            if let index = items(line).firstIndex(where: {
                $0.pick == pick
            }), matches(line).contains(index) {
                selection = Position(line: line, index: index)
                return
            }
        }
    }

    /// ⌘1–9: the selected line's item at that number.
    func quick(_ index: Int) -> Item? {
        guard let line = selection?.line else { return nil }
        let order = matches(line)
        guard index < 9, order.indices.contains(index) else {
            return nil
        }
        return items(line)[order[index]]
    }

    /// The line's current item, else its first.
    private func resting(on line: Line) -> Position? {
        let all = items(line)
        guard !all.isEmpty else { return nil }
        return Position(
            line: line,
            index: all.firstIndex(where: \.isCurrent) ?? 0
        )
    }
}
