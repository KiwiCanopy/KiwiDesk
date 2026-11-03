import Foundation

/// The live chord beside a window row of a bar menu (#2869, owner
/// ruling 2026-11-01 in its body): only where pressing it does
/// exactly what clicking the row does.
extension KiwiCore {
    /// `verb`'s live chord for a row acting on `id` in a menu
    /// standing for `menu`: a single-window menu whose window holds
    /// the focus the bars show (`barFocus`) and the one the key
    /// acts on (`focusedWindowID`); nil in a group menu, parent or
    /// child, and for any other window, as for an unbound row.
    func barMenuChord(
        _ verb: BarMenuVerb,
        for id: WindowID,
        in menu: [WindowID]
    ) -> KeyCombo? {
        guard menu == [id], barFocus(on: nil) == id,
            focusedWindowID == id
        else { return nil }
        return barMenuHooks.menuChord(verb)
    }
}
