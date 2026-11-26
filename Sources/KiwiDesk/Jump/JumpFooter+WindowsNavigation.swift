import AppKit
import KiwiDeskCore

/// The Windows footer's navigation hints and the order they shed
/// in (#3159, #3667).
extension JumpFooter {
    /// The Windows side's navigation hints: ← → along the strip,
    /// the last-app opener, then the side switch last (#3667). The
    /// opener sheds first (#3159), then the side switch, then ← →.
    func windowsNavigation(
        _ held: NSEvent.ModifierFlags
    ) -> [JumpFooterSlot] {
        func slot(_ text: String, sheds: Int) -> JumpFooterSlot {
            JumpFooterSlot(text: text, keycap: nil, held: false, sheds: sheds)
        }
        var hints: [JumpFooterSlot] = []
        if stripSteps {
            hints.append(
                slot(
                    L("jump.footer.apps", "%1$@ Apps", "← →"),
                    sheds: JumpFooterSlot.appsSheds
                )
            )
        }
        if let opener = openerHint(Self.held(held)) {
            hints.append(slot(opener, sheds: JumpFooterSlot.openerSheds))
        }
        hints.append(
            slot(sideHint(held), sheds: JumpFooterSlot.sideSheds)
        )
        return hints
    }

    /// The opener's entry for `held`: its back form where `held`
    /// completes that chord, else Next app; nil where it is unbound.
    func openerHint(_ held: NSEvent.ModifierFlags) -> String? {
        guard let lastAppChord else { return nil }
        if let back = completedBack(held) {
            return L(
                "jump.footer.previous_app",
                "%1$@ Previous app",
                ChordGlyphs.render(back, layoutChar: LayoutKeyGlyph.char)
            )
        }
        return L("jump.footer.next_app", "%1$@ Next app", lastAppChord)
    }

    /// The opener's back chord, where `held` is its modifiers.
    private func completedBack(_ held: NSEvent.ModifierFlags) -> KeyCombo? {
        guard let back = JumpKey.back(of: lastAppCombo),
            KeyCombo(keyCode: UInt16(back.keyCode), flags: held) == back
        else { return nil }
        return back
    }

    /// Whether `held` completes the opener's chord or its back form.
    func openerLit(_ held: NSEvent.ModifierFlags) -> Bool {
        guard lastAppChord != nil, let opener = lastAppCombo?.registered
        else { return false }
        if completedBack(held) != nil { return true }
        return KeyCombo(keyCode: UInt16(opener.keyCode), flags: held)
            == opener
    }

    /// The slots a line of `shown` keeps, in their order: the
    /// highest `sheds` goes first, then the rest from the end.
    static func kept(_ slots: [JumpFooterSlot], shown: Int?) -> [Int] {
        let shown = shown ?? slots.count
        let order = slots.indices.sorted {
            (slots[$0].sheds, $0) > (slots[$1].sheds, $1)
        }
        let dropped = Set(order.prefix(max(slots.count - shown, 0)))
        return slots.indices.filter { !dropped.contains($0) }
    }
}
