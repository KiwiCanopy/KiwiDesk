import Foundation
import KiwiDeskCore

/// What the Desktops side's field asks for (#1229 ▸ Search, #3624):
/// an all-digit query names a Desktop by its number in each screen
/// column, as ⌘N counts, and anything else is app and title text.
enum DesktopsSearch: Equatable {
    case all
    /// Desktop N, 1-based; nil where the digits overflow.
    case number(Int?)
    case text(String)

    init(_ query: String) {
        let typed = query.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            self = .all
        } else if !typed.isEmpty, typed.allSatisfy(Self.isDigit) {
            self = .number(Int(typed))
        } else {
            self = .text(query)
        }
    }

    private static func isDigit(_ character: Character) -> Bool {
        ("0"..."9").contains(character)
    }
}

/// Matching and match-only reach (#3624 ▸ Ruling, after #3135):
/// under a query the keys land only on matches, save that a carry
/// reaches every line, since a drop's target is a place.
extension DesktopsState {
    var search: DesktopsSearch { DesktopsSearch(query) }

    /// Whether `window`, drawn on `place`, matches what is typed.
    /// A number matches the windows of its Desktop's lines, never a
    /// window's text.
    func matches(
        _ window: DesktopOverview.Window,
        at place: DesktopsPlace
    ) -> Bool {
        switch search {
        case .all: return true
        case .number(let number): return place.desktop + 1 == number
        case .text(let text):
            return window.app.localizedCaseInsensitiveContains(text)
                || window.title.localizedCaseInsensitiveContains(text)
        }
    }

    /// Whether the keys may land on `place`; a place they may not
    /// dims. Everything is reachable while nothing is typed or a
    /// window is carried.
    func hasMatch(_ place: DesktopsPlace) -> Bool {
        switch search {
        case .all: return true
        case _ where isCarrying: return true
        case .number(let number): return place.desktop + 1 == number
        case .text:
            let windows = line(place)?.windows ?? []
            return windows.contains { matches($0, at: place) }
        }
    }

    /// Whether the keys may land on `window` inside `place`.
    func reaches(
        _ window: DesktopOverview.Window,
        at place: DesktopsPlace
    ) -> Bool {
        isCarrying || matches(window, at: place)
    }

    /// The windows of `place` the keys may land on, as drawn.
    func reachable(_ place: DesktopsPlace) -> [DesktopOverview.Window] {
        ordered(place).filter { reaches($0, at: place) }
    }

    /// True while a query matches no place: the keys that move or
    /// act beep and the selection stays.
    var matchesNothing: Bool {
        overview.screens.indices.allSatisfy { screen in
            !columnOrder(screen: screen).contains(where: hasMatch)
        }
    }

    /// The place a query lands on in `screen`'s column: Desktop N's
    /// landing line for a number, else the first match down it.
    func firstMatch(screen: Int) -> DesktopsPlace? {
        if case .number(let number?) = search, !isCarrying,
            let place = numbered(number - 1, screen: screen)
        {
            return place
        }
        return columnOrder(screen: screen).first(where: hasMatch)
    }

    /// Moves a selection the query dims to the first match in its
    /// screen's column, then the next column's; a selection still
    /// matching stays.
    mutating func settle() {
        guard let place, !hasMatch(place) else { return }
        let screens = overview.screens.indices
        let order =
            screens.filter { $0 >= place.screen }
            + screens.filter { $0 < place.screen }
        guard let found = order.lazy.compactMap(firstMatch).first else {
            return
        }
        select(found)
    }
}
