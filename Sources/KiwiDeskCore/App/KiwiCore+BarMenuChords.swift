import Foundation

/// The live chord beside a window row of a bar menu (#2869, owner
/// ruling 2026-11-01 in its body): only where pressing it does
/// exactly what clicking the row does.
extension KiwiCore {
    /// `verb`'s live chord for a row acting on `windows`: a
    /// single-window menu whose window holds the focus (`barFocus`),
    /// since the key acts on the focus alone; nil for a group menu
    /// and for any other window, as for an unbound row.
    func barMenuChord(
        _ verb: BarMenuVerb,
        for windows: [WindowID]
    ) -> KeyCombo? {
        guard windows.count == 1, barFocus(on: nil) == windows[0]
        else { return nil }
        return barMenuHooks.menuChord(verb)
    }
}
