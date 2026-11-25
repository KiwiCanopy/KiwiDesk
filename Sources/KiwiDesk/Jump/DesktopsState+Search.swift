import Foundation
import KiwiDeskCore

/// What the Desktops side's field asks for (#1229, #3624):
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
        character.isASCII && character.isWholeNumber
    }
}

/// Matching and match-only reach (#3624 ▸ Ruling, after #3135):
/// under a query the keys land only on matches, save that a carry
/// reaches every line, since a drop's target is a place. Windows
/// stay match-only during a carry, as their icons stay dimmed.
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
        case .number(let number): return isNumbered(place, number)
        case .text(let text):
            return window.app.localizedCaseInsensitiveContains(text)
                || window.title.localizedCaseInsensitiveContains(text)
        }
    }

    /// Whether the keys may land on `place`; a line they may not
    /// dims. Every line is reachable while nothing is typed or a
    /// window is carried.
    func reaches(_ place: DesktopsPlace) -> Bool {
        switch search {
        case .all: return true
        case _ where isCarrying: return true
        case .number(let number): return isNumbered(place, number)
        case .text:
            let windows = line(place)?.windows ?? []
            return windows.contains { matches($0, at: place) }
        }
    }

    /// Whether the keys may land on `window` inside `place`: the
    /// windows whose icons the query leaves undimmed.
    func reaches(
        _ window: DesktopOverview.Window,
        at place: DesktopsPlace
    ) -> Bool {
        matches(window, at: place)
    }

    /// The windows of `place` the keys may land on, as drawn.
    func reachable(_ place: DesktopsPlace) -> [DesktopOverview.Window] {
        ordered(place).filter { reaches($0, at: place) }
    }

    /// True while a typed query matches no place: the keys that move
    /// or act beep and the selection stays.
    var matchesNothing: Bool {
        guard search != .all else { return false }
        return overview.screens.indices.allSatisfy { screen in
            !columnOrder(screen: screen).contains(where: reaches)
        }
    }

    /// The place a query lands on in `screen`'s column: Desktop N's
    /// landing line for a number, else the first match down it.
    func firstMatch(screen: Int) -> DesktopsPlace? {
        if case .number(let number?) = search,
            let place = numbered(number - 1, screen: screen)
        {
            return place
        }
        return columnOrder(screen: screen).first(where: reaches)
    }

    /// The match down `place`'s column nearest it, `place` itself
    /// where it matches; a tie goes up.
    func nearestMatch(to place: DesktopsPlace) -> DesktopsPlace? {
        let order = columnOrder(screen: place.screen)
        guard let at = order.firstIndex(of: place) else { return nil }
        return order.indices.filter { reaches(order[$0]) }
            .min { abs($0 - at) < abs($1 - at) }
            .map { order[$0] }
    }

    /// Puts the selection where the keys may land, the one door every
    /// query change and carry end passes (#3624): a window the query
    /// dims leaves the Space, and a line it dims gives way to the
    /// first match in its screen's column, then the next column's.
    /// A selection still matching stays. A new writer of `query` or
    /// `carried` calls it; a re-read moves a clicked dimmed
    /// selection too.
    mutating func settle() {
        if let window, let place, let found = overview.window(window),
            !reaches(found, at: place)
        {
            leave()
        }
        guard let place, !reaches(place) else { return }
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
