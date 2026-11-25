import KiwiDeskCore

/// Matching and match-only reach (#3624 ▸ Ruling, after #3135):
/// under a query the keys land only on matches, save that a carry
/// reaches every line under a query standing at its pick-up, since
/// a drop's target is a place; a query edited during the carry
/// steers it like a search. Windows stay match-only during a carry,
/// as their icons stay dimmed.
extension DesktopsState {
    /// Whether the keys may land on `place`; a line they may not
    /// dims. Every line is reachable while nothing is typed, or
    /// while a window is carried under the query standing at its
    /// pick-up.
    func reaches(_ place: DesktopsPlace) -> Bool {
        guard !query.isEmpty, !isCarrying || queryLeadsCarry else {
            return true
        }
        return line(place)?.windows.contains(where: matches) ?? false
    }

    /// The windows of `place` the keys may land on, as drawn: the
    /// ones whose icons the query leaves undimmed.
    func reachable(_ place: DesktopsPlace) -> [DesktopOverview.Window] {
        ordered(place).filter(matches)
    }

    /// True while a typed query matches no place: the keys that move
    /// or act beep and the selection stays.
    var matchesNothing: Bool {
        guard !query.isEmpty else { return false }
        return overview.screens.indices.allSatisfy { screen in
            !columnOrder(screen: screen).contains(where: reaches)
        }
    }

    /// The first match down `screen`'s column.
    func firstMatch(screen: Int) -> DesktopsPlace? {
        columnOrder(screen: screen).first(where: reaches)
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
        if let window, let found = overview.window(window),
            !matches(found)
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
