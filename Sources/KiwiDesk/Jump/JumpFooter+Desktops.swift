import AppKit
import KiwiDeskCore
import SwiftUI

/// What the Desktops side's footer reads of its state (#1229).
struct DesktopsFooterState: Equatable {
    var isInside = false
    var isCarrying = false
    /// Whether the selected window is one of the picked.
    var selectionPicked = false
    /// Whether ⌘↩ would pick up or put back the selected window;
    /// a refused one lights nothing (#3170, as #2246).
    var selectionPickable = false
    /// How many Desktops the ⌘ digits reach on the selected row.
    var digits = 0
    /// The refusal shown in place of the hints until the next key,
    /// click or selection change (#3170).
    var refusal: String?

    init(_ state: DesktopsState, refusal: String? = nil) {
        isInside = state.isInside
        isCarrying = state.isCarrying
        selectionPicked = state.window.map(state.carried.contains) ?? false
        selectionPickable =
            state.window.map { id in
                state.carried.contains(id)
                    || state.overview.window(id)?.block == nil
            } ?? false
        digits = state.digitCount
        self.refusal = refusal
    }
}

/// The Desktops side's hints, most important first, shed from the
/// end; ↩ and ⇧↩, or ↩ ⌃↩ Esc while carrying, never shed.
/// Holding ⇧, ⌥ or ⌘ rewrites them as on the other sides.
extension JumpFooter {
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
        let second = DesktopsText.moveThere
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
        if held.contains(.command) {
            guard desktops.isInside else { return 3 }
            return desktops.selectionPickable ? 2 : nil
        }
        if held.contains(.shift) || held.contains(.option) { return 1 }
        return 0
    }

    /// A refusal in place of the hints: the Windows side's glyph
    /// and words (#3170). VoiceOver hears it through `onRefuse`.
    func desktopsRefusal(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "nosign")
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .accessibilityHidden(true)
    }
}
