import CoreGraphics
import KiwiDeskCore

/// The Desktops side's arrows (#1229, #3570 ruling 4). Each screen
/// is a column: among places ↑↓ walk its Desktops' lines top to
/// bottom, across area groups (#3572), and ←→ step to the
/// neighbouring screen, keeping the Desktop and line where they
/// can; in the shared-Desktop grid they stay in the Desktop's row
/// and land on the line nearest the one they left (#3602). Inside
/// a Space ←→ walk its windows and ↑↓ take the places' route,
/// re-entering where a line holds windows (#3169). Under a query
/// every move lands only on a match (#3624), stepping past dimmed
/// lines, windows and screens. A fresh press wraps at an end, a
/// held key stops there (#2897).
extension DesktopsState {
    /// ↑ / ↓ among places.
    mutating func moveLine(_ delta: Int, wrap: Bool) {
        guard let place else { return }
        let order = columnOrder(screen: place.screen)
        guard
            let next = Self.step(
                from: place,
                among: order.filter(reaches),
                order: order,
                delta,
                wrap: wrap
            )
        else { return }
        select(next)
    }

    /// ← / → among screens, keeping the Desktop and the line where
    /// the next screen has them; under a query, skipping a screen
    /// with no match and landing on the match nearest that place.
    mutating func moveScreen(_ delta: Int, wrap: Bool) {
        guard let place else { return }
        let screens = Array(overview.screens.indices)
        let stops = screens.filter {
            columnOrder(screen: $0).contains(where: reaches)
        }
        guard
            let screen = Self.step(
                from: place.screen,
                among: stops,
                order: screens,
                delta,
                wrap: wrap
            )
        else { return }
        let desktops = overview.screens[screen].desktops
        let desktop = min(place.desktop, desktops.count - 1)
        let line =
            geometry.grid == nil
            ? place.line
            : nearestLine(to: place, on: screen, desktop: desktop)
        let kept = clamped(screen: screen, desktop: desktop, line: line)
        select(nearestMatch(to: kept) ?? kept)
    }

    /// The line of `desktop` on `screen` whose top lies nearest the
    /// top of `place`'s line, both read from their cells' tops; a
    /// tie goes up.
    func nearestLine(
        to place: DesktopsPlace,
        on screen: Int,
        desktop: Int
    ) -> Int {
        guard let source = self.desktop(place) else { return place.line }
        let line = geometry.line
        let from = DesktopsGeometry.lineTop(
            of: source,
            at: place.line,
            line: line
        )
        let target = overview.screens[screen].desktops[desktop]
        let distances = target.spaces.indices.map {
            abs(
                DesktopsGeometry.lineTop(of: target, at: $0, line: line)
                    - from
            )
        }
        guard let least = distances.min() else { return 0 }
        return distances.firstIndex(of: least) ?? 0
    }

    /// ← / → inside a Space: the next window as drawn.
    mutating func stepWindow(_ delta: Int, wrap: Bool) {
        guard let place, let window else { return }
        let drawn = ordered(place).map(\.id)
        let stops = reachable(place).map(\.id)
        guard
            let next = Self.step(
                from: window,
                among: stops,
                order: drawn,
                delta,
                wrap: wrap
            )
        else { return }
        select(window: next, in: place)
    }

    /// ↑ / ↓ inside a Space: the same route as among places
    /// (#3169). A line with windows is re-entered on the window
    /// under the slot it left; an empty line is selected, leaving
    /// the Space.
    mutating func stepLineInside(_ delta: Int, wrap: Bool) {
        guard let place, let index = windowIndex else { return }
        let slot = index - offset(place)
        let order = columnOrder(screen: place.screen)
        guard
            let target = Self.step(
                from: place,
                among: order.filter(reaches),
                order: order,
                delta,
                wrap: wrap
            )
        else { return }
        // Matches lead the drawn order, so the reachable windows
        // are its first ones.
        let drawn = reachable(target)
        guard !drawn.isEmpty else { return select(target) }
        let pick = min(offset(target) + slot, drawn.count - 1)
        select(window: drawn[pick].id, in: target)
    }

    /// The Desktop ⌘ and digit `index` (0-based) names in the
    /// selected screen's column, on its landing line.
    func desktop(digit index: Int) -> DesktopsPlace? {
        guard let place else { return nil }
        let desktops = overview.screens[place.screen].desktops
        guard desktops.indices.contains(index) else { return nil }
        return clamped(
            screen: place.screen,
            desktop: index,
            line: desktops[index].landingLine
        )
    }

    /// How many Desktops the selected column's digits reach.
    var digitCount: Int {
        guard let place else { return 0 }
        return min(overview.screens[place.screen].desktops.count, 9)
    }

    /// Every place down a screen's column: each Desktop's lines in
    /// turn, top to bottom.
    func columnOrder(screen: Int) -> [DesktopsPlace] {
        let desktops = overview.screens[screen].desktops
        return desktops.indices.flatMap { desktop in
            desktops[desktop].spaces.indices.map {
                DesktopsPlace(screen: screen, desktop: desktop, line: $0)
            }
        }
    }

    private func clamped(
        screen: Int,
        desktop: Int,
        line: Int
    ) -> DesktopsPlace {
        let lines = overview.screens[screen].desktops[desktop].spaces
        return DesktopsPlace(
            screen: screen,
            desktop: desktop,
            line: max(0, min(line, lines.count - 1))
        )
    }

    /// One step from `index` through KiwiHub's one list step
    /// (gui.md ▸ #2897): a fresh press wraps, a held key and a page
    /// stop at the end; nil where nothing moved.
    static func step(
        _ index: Int,
        _ delta: Int,
        count: Int,
        wrap: Bool
    ) -> Int? {
        guard count > 0 else { return nil }
        let next = JumpList.stepped(index, by: delta, count: count, wrap: wrap)
        return next == index ? nil : next
    }

    /// One step from `item` among `stops`, the items of `order` the
    /// keys may land on. From an item that is no stop, the step
    /// lands on the nearest stop in its direction, and past the
    /// last one takes the list step's wrap from that end.
    static func step<Item: Equatable>(
        from item: Item,
        among stops: [Item],
        order: [Item],
        _ delta: Int,
        wrap: Bool
    ) -> Item? {
        if let at = stops.firstIndex(of: item) {
            return step(at, delta, count: stops.count, wrap: wrap)
                .map { stops[$0] }
        }
        guard let at = order.firstIndex(of: item), !stops.isEmpty else {
            return nil
        }
        let before = stops.filter {
            (order.firstIndex(of: $0) ?? at) < at
        }.count
        let land = delta > 0 ? before : before - 1
        if stops.indices.contains(land) { return stops[land] }
        // Past the last stop: the list step's own wrap from that end,
        // which a held key never takes.
        guard wrap else { return nil }
        let edge = delta > 0 ? stops.count - 1 : 0
        let by = delta > 0 ? 1 : -1
        return stops[
            JumpList.stepped(edge, by: by, count: stops.count, wrap: true)
        ]
    }
}
