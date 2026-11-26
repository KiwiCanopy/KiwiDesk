import AppKit
import KiwiDeskCore

/// The Windows footer's navigation hints and the order they shed
/// in (#3159, #3667).
extension JumpFooter {
    /// The Windows side's navigation hints: ← → along the strip,
    /// the last-app opener, then the side switch last (#3667).
    func windowsNavigation(
        _ held: NSEvent.ModifierFlags
    ) -> [JumpFooterSlot] {
        func slot(_ text: String, _ role: JumpFooterSlot.Role)
            -> JumpFooterSlot
        {
            JumpFooterSlot(text: text, keycap: nil, held: false, role: role)
        }
        var hints: [JumpFooterSlot] = []
        if stripSteps {
            hints.append(
                slot(L("jump.footer.apps", "%1$@ Apps", "← →"), .apps)
            )
        }
        if let opener = openerHint(held) {
            hints.append(slot(opener, .opener))
        }
        hints.append(slot(sideHint(held), .side))
        return hints
    }

    /// The opener drawn, nil where it is unbound.
    private var openerChord: String? {
        lastAppCombo.map {
            ChordGlyphs.render($0, layoutChar: LayoutKeyGlyph.char)
        }
    }

    /// The opener's entry for `held`: its back form where `held`
    /// presses that chord, else Next app; nil where it is unbound.
    func openerHint(_ held: NSEvent.ModifierFlags) -> String? {
        guard let openerChord else { return nil }
        if let back = pressedBack(held) {
            return L(
                "jump.footer.previous_app",
                "%1$@ Previous app",
                ChordGlyphs.render(back, layoutChar: LayoutKeyGlyph.char)
            )
        }
        return L("jump.footer.next_app", "%1$@ Next app", openerChord)
    }

    /// The opener's back chord, where `held` with its key presses it,
    /// read through the panel's own match.
    private func pressedBack(_ held: NSEvent.ModifierFlags) -> KeyCombo? {
        guard let back = JumpKey.back(of: lastAppCombo),
            let code = UInt16(exactly: back.keyCode),
            JumpKey.isBack(
                keyCode: code,
                modifiers: held,
                scope: .windows,
                back: back
            )
        else { return nil }
        return back
    }

    /// Whether `held` presses the opener or its back form.
    func openerLit(_ held: NSEvent.ModifierFlags) -> Bool {
        if pressedBack(held) != nil { return true }
        guard let opener = lastAppCombo,
            let code = UInt16(exactly: opener.keyCode)
        else { return false }
        return JumpKey.isOpener(keyCode: code, modifiers: held, opener: opener)
    }

    /// The slots a line of `shown` keeps, in their order: the
    /// opener goes first, then the side switch, then ← →, then the
    /// rest from the end (#3159, #3667).
    static func kept(_ slots: [JumpFooterSlot], shown: Int?) -> [Int] {
        let shown = shown ?? slots.count
        let order = slots.indices.sorted {
            (slots[$0].role.sheds, $0) > (slots[$1].role.sheds, $1)
        }
        let dropped = Set(order.prefix(max(slots.count - shown, 0)))
        return slots.indices.filter { !dropped.contains($0) }
    }
}
