import KiwiDeskCore

/// The Desktops side's arrows (#1229, #3570 ruling 4). Each screen
/// is a column: among places ↑↓ walk its Desktops' lines top to
/// bottom, across area groups (#3572), and ←→ step to the
/// neighbouring screen, keeping the Desktop and line where they
/// can. Inside a Space ←→ walk its windows and ↑↓ take the places'
/// route, re-entering where a line holds windows (#3169). A fresh
/// press wraps at an end, a held key stops there (#2897).
extension DesktopsState {
    /// ↑ / ↓ among places.
    mutating func moveLine(_ delta: Int, wrap: Bool) {
        guard let place else { return }
        let order = columnOrder(screen: place.screen)
        guard let index = order.firstIndex(of: place) else { return }
        guard
            let next = Self.step(index, delta, count: order.count, wrap: wrap)
        else { return }
        select(order[next])
    }

    /// ← / → among screens, keeping the Desktop and the line where
    /// the next screen has them.
    mutating func moveScreen(_ delta: Int, wrap: Bool) {
        guard let place else { return }
        let screens = overview.screens.indices.filter {
            !overview.screens[$0].desktops.isEmpty
        }
        guard let at = screens.firstIndex(of: place.screen),
            let next = Self.step(at, delta, count: screens.count, wrap: wrap)
        else { return }
        let screen = screens[next]
        let desktops = overview.screens[screen].desktops
        select(
            clamped(
                screen: screen,
                desktop: min(place.desktop, desktops.count - 1),
                line: place.line
            )
        )
    }

    /// ← / → inside a Space: the next window as drawn.
    mutating func stepWindow(_ delta: Int, wrap: Bool) {
        guard let place, let index = windowIndex else { return }
        let drawn = ordered(place)
        guard
            let next = Self.step(index, delta, count: drawn.count, wrap: wrap)
        else { return }
        select(window: drawn[next].id, in: place)
    }

    /// ↑ / ↓ inside a Space: the same route as among places
    /// (#3169). A line with windows is re-entered on the window
    /// under the slot it left; an empty line is selected, leaving
    /// the Space.
    mutating func stepLineInside(_ delta: Int, wrap: Bool) {
        guard let place, let index = windowIndex else { return }
        let slot = index - offset(place)
        let order = columnOrder(screen: place.screen)
        guard let at = order.firstIndex(of: place),
            let next = Self.step(at, delta, count: order.count, wrap: wrap)
        else { return }
        let target = order[next]
        let drawn = ordered(target)
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
}
