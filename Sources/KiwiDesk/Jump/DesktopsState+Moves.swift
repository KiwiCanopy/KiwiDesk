import KiwiDeskCore

/// The Desktops side's arrows (#1229). Among places ↑↓ walk a
/// card's lines and on to the screen row above or below, ←→ walk a
/// row's cards; inside a Space ←→ walk its windows and ↑↓ go to the
/// nearest window in the neighbouring line. A fresh press wraps at
/// an end, a held key stops there (#2897).
extension DesktopsState {
    /// ↑ / ↓ among places.
    mutating func moveLine(_ delta: Int, wrap: Bool) {
        guard let place else { return }
        let order = verticalOrder(column: place.desktop)
        guard let index = order.firstIndex(of: place) else { return }
        guard
            let next = Self.step(index, delta, count: order.count, wrap: wrap)
        else { return }
        select(order[next])
    }

    /// ← / → among a row's cards, keeping the line where it can.
    mutating func moveCard(_ delta: Int, wrap: Bool) {
        guard let place else { return }
        let count = overview.screens[place.screen].desktops.count
        guard
            let next = Self.step(
                place.desktop,
                delta,
                count: count,
                wrap: wrap
            )
        else { return }
        select(clamped(screen: place.screen, desktop: next, line: place.line))
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

    /// ↑ / ↓ inside a Space: the window under the same slot in the
    /// nearest line of the card that holds one.
    mutating func stepLineInside(_ delta: Int) {
        guard let place, let index = windowIndex,
            let desktop = desktop(place)
        else { return }
        let slot = index - offset(place)
        var line = place.line + delta
        while desktop.spaces.indices.contains(line) {
            let target = DesktopsPlace(
                screen: place.screen,
                desktop: place.desktop,
                line: line
            )
            let drawn = ordered(target)
            if !drawn.isEmpty {
                let pick = min(offset(target) + slot, drawn.count - 1)
                select(window: drawn[pick].id, in: target)
                return
            }
            line += delta
        }
    }

    /// The Desktop ⌘ and digit `index` (0-based) names on the
    /// selected screen's row.
    func desktop(digit index: Int) -> DesktopsPlace? {
        guard let place else { return nil }
        let desktops = overview.screens[place.screen].desktops
        guard desktops.indices.contains(index) else { return nil }
        let lines = desktops[index].spaces
        let line = lines.firstIndex(where: \.isShown) ?? 0
        return clamped(screen: place.screen, desktop: index, line: line)
    }

    /// How many Desktops the selected row's digits reach.
    var digitCount: Int {
        guard let place else { return 0 }
        return min(overview.screens[place.screen].desktops.count, 9)
    }

    /// Every place down a column: each screen's card at `column`, or
    /// its last where it has fewer, line by line.
    private func verticalOrder(column: Int) -> [DesktopsPlace] {
        overview.screens.indices.flatMap { screen -> [DesktopsPlace] in
            let desktops = overview.screens[screen].desktops
            guard !desktops.isEmpty else { return [] }
            let desktop = min(column, desktops.count - 1)
            return desktops[desktop].spaces.indices.map {
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

    /// One step from `index`, wrapping only where asked; nil where
    /// the step leaves nothing to land on.
    static func step(
        _ index: Int,
        _ delta: Int,
        count: Int,
        wrap: Bool
    ) -> Int? {
        guard count > 0 else { return nil }
        let next = index + delta
        if (0..<count).contains(next) { return next }
        guard wrap else { return nil }
        return (next % count + count) % count
    }
}
