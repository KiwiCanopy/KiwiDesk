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
            state.window.map { state.pickBlock($0) == nil } ?? false
        digits = state.digitCount
        self.refusal = refusal
    }
}

/// The Desktops side's hints, most important first, shed from the
/// end; ↩ and ⇧↩, or ↩ ⌃↩ Esc while carrying, never shed, and the
/// side switch stands last (#3667). Holding ⇧, ⌥ or ⌘ rewrites
/// them as on the other sides.
extension JumpFooter {
    var desktopsHints: [String] {
        guard let desktops else { return [] }
        let next = sideHint(modifiers)
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
            if desktops.isInside {
                return carry + [pick, DesktopsText.back, next]
            }
            let drop = DesktopsText.dropDesktop(digits)
            return carry + (desktops.digits > 0 ? [drop] : []) + [next]
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

    /// The hints the held keys complete, as indices into
    /// `desktopsHints`, the side switch aside (#3667): the chord
    /// each hint is written with, where that press acts — a dead
    /// chord lights nothing.
    var desktopsLit: Set<Int> {
        guard let desktops else { return [] }
        let held = Self.held(modifiers)
        let hasDigits = desktops.digits > 0
        if desktops.isCarrying {
            // ↩ Drop · ⌃↩ · Esc · then Pick up · ⌘↑ Back inside,
            // or the ⌘ digits outside.
            switch held {
            case []: return [0]
            case .command where desktops.isInside:
                return desktops.selectionPickable ? [3, 4] : [4]
            case .command: return hasDigits ? [3] : []
            default: return []
            }
        }
        if desktops.isInside {
            // ↩ Jump · ⇧↩ / ⌥↩ · ⌘↩ Pick up · ⌘↑ Back.
            switch held {
            case []: return [0]
            case .shift, .option, [.shift, .option]: return [1]
            case .command:
                return desktops.selectionPickable ? [2, 3] : [3]
            default: return []
            }
        }
        // ↩ Jump · ⇧↩ there · ⌘↓ Open Space · the ⌘ digits.
        switch held {
        case []: return [0]
        case .shift: return [1]
        case .command: return hasDigits ? [2, 3] : [2]
        case [.shift, .command]: return hasDigits ? [3] : []
        default: return []
        }
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
