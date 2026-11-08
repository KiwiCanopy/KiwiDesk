import AppKit
import KiwiDeskCore

/// What the Desktops side's footer reads of its state (#1229).
struct DesktopsFooterState: Equatable {
    var isInside = false
    var isCarrying = false
    /// Whether the selected window is one of the picked.
    var selectionPicked = false
    /// How many Desktops the ⌘ digits reach on the selected row.
    var digits = 0

    init(_ state: DesktopsState) {
        isInside = state.isInside
        isCarrying = state.isCarrying
        selectionPicked = state.window.map(state.carried.contains) ?? false
        digits = state.digitCount
    }
}

/// The Desktops side's hints, most important first, shed from the
/// end; ↩ and ⇧↩, or ↩ ⌃↩ Esc while carrying, never shed.
/// Holding ⇧, ⌥ or ⌘ rewrites them as on the other sides.
extension JumpFooter {
    /// How many leading hints never shed.
    var keeps: Int {
        guard scope == .desktops, let desktops else { return 0 }
        return min(desktops.isCarrying ? 3 : 2, hints.count)
    }

    var desktopsHints: [String] {
        guard let desktops else { return [] }
        let next = L(
            "jump.footer.scope",
            "%1$@ %2$@",
            "⇥",
            scope.stepped(forward: true).title
        )
        let digits =
            desktops.digits > 1
            ? "⌘1–\(desktops.digits)" : "⌘1"
        let pick =
            desktops.selectionPicked
            ? DesktopsText.putBack : DesktopsText.pickUp
        if desktops.isCarrying {
            let carry = [
                DesktopsText.drop, DesktopsText.dropFollow,
                DesktopsText.cancel,
            ]
            if desktops.isInside { return carry + [pick, DesktopsText.back] }
            let drop = DesktopsText.dropDesktop(digits)
            return carry + (desktops.digits > 0 ? [drop] : [])
        }
        if desktops.isInside {
            let second =
                modifiers.contains(.option)
                ? DesktopsText.swapHere : DesktopsText.moveHere
            return [DesktopsText.jump, second, pick, DesktopsText.back, next]
        }
        let second =
            modifiers.contains(.control)
            ? DesktopsText.moveFollow : DesktopsText.moveThere
        let desktop =
            modifiers.contains(.shift)
            ? DesktopsText.moveDesktop("⇧" + digits)
            : DesktopsText.jumpDesktop(digits)
        return [DesktopsText.jump, second, DesktopsText.openSpace]
            + (desktops.digits > 0 ? [desktop] : []) + [next]
    }

    /// The hint the modifiers held now name, in full ink.
    var desktopsLeading: Int? {
        guard let desktops else { return nil }
        let held = modifiers.intersection([.shift, .option, .command])
        if desktops.isCarrying {
            return held.contains(.command) && !desktops.isInside ? 3 : 0
        }
        if held.contains(.command) { return desktops.isInside ? 2 : 3 }
        if held.contains(.shift) || held.contains(.option) { return 1 }
        return 0
    }
}
