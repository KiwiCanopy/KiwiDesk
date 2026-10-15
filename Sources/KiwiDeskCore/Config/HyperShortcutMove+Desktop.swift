import Foundation

/// The Hyper move's Desktop line (#1870): the Go to Desktop rows on
/// their seeded chord, and the base the line sets.
extension HyperShortcutMove {
    /// The line `rows` earn while `base` is the one `direction`
    /// leaves. Forward, it is offered only while a seeded Desktop
    /// row would move or stay, so a declined line retires with the
    /// letters; the reverse stays while the base is Hyper, since it
    /// alone resets the base for Desktops added later.
    static func desktopLine(
        _ direction: Direction,
        rows: [KeyBinding],
        base: DesktopShortcutBase
    ) -> DesktopLine? {
        let toHyper = direction == .toHyper
        let from: DesktopShortcutBase = toHyper ? .standard : .hyper
        let to: DesktopShortcutBase = toHyper ? .hyper : .standard
        guard base == from else { return nil }
        var moves: [Move] = []
        var kept: [Kept] = []
        for number in 1...DefaultKeybindings.digitCapacity {
            guard
                let seeded = DefaultKeybindings.desktopRow(
                    number,
                    base: from
                ),
                let next = DefaultKeybindings.desktopRow(number, base: to),
                let row = rows.first(where: {
                    $0.lua == seeded.lua
                        && KeyCombo.equivalent($0.combo, seeded.combo)
                })
            else { continue }
            let move = Move(lua: row.lua, from: row.combo, to: next.combo)
            if let holder = holder(of: [move], in: rows) {
                kept.append(Kept(move: move, holder: holder))
            } else {
                moves.append(move)
            }
        }
        if toHyper, moves.isEmpty, kept.isEmpty { return nil }
        return DesktopLine(moves: moves, kept: kept, from: from, base: to)
    }
}
