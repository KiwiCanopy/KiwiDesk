import Foundation

/// One row's own Move to Hyper (#2420): any row on `⌃⌥` or `⌥⌘`,
/// `⇧` kept, the user's pick rather than the offer's, so the
/// offer's rule that the ladder and the size base stay put does
/// not bind it (`docs/design-decisions.md` ▸ A row moves itself).
extension HyperShortcutMove {
    /// What a row's Move to Hyper does.
    public enum RowMove: Equatable, Sendable {
        /// The row moves onto `to`.
        case move(to: String)
        /// `to` is held by `holder`, so the row stays.
        case taken(to: String, by: KeyBinding)
    }

    /// The bases a row moves from: exactly one of them, plus `⇧` at
    /// most, so the `⌃⌥⇧⌘` Desktop tier and `⌘`-only chords stay.
    static let rowBases: [HotkeyModifiers] = [
        letterBase, [.option, .command],
    ]

    /// `row`'s move among `rows`, or nil where it is offered none:
    /// already on `✦`, app chrome, or on neither base.
    public static func rowMove(
        _ row: KeyBinding,
        in rows: [KeyBinding]
    ) -> RowMove? {
        guard !isChrome(row), let combo = KeyCombo.parse(row.combo),
            let to = rowTarget(combo)?.comboString()
        else { return nil }
        let move = Move(lua: row.lua, from: row.combo, to: to)
        if let holder = holder(of: [move], in: rows) {
            return .taken(to: to, by: holder)
        }
        return .move(to: to)
    }

    /// `combo` with its base swapped for `✦`, or nil off both bases;
    /// the `⌃⌥` base takes the offer's own `moved`.
    static func rowTarget(_ combo: KeyCombo) -> KeyCombo? {
        let base = combo.modifiers.subtracting(.shift)
        guard rowBases.contains(base) else { return nil }
        if base == letterBase { return moved(combo, .toHyper) }
        return KeyCombo(
            keyCode: combo.keyCode,
            modifiers: combo.modifiers.subtracting(base).union(.hyper)
        )
    }
}
