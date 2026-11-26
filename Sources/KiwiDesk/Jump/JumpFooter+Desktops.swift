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

/// One Desktops hint: its words and the chord they name, which
/// lights it where the held keys press the same key (#3667).
struct DesktopsHint {
    let text: String
    /// The key the hint names; nil for the side switch, which
    /// `JumpFooter.lit` lights itself.
    var key: UInt16?
    var chord: NSEvent.ModifierFlags = []
    /// Whether the press would act on the selection.
    var live = true
}

/// The Desktops side's hints, most important first, shed from the
/// end; ↩ and ⇧↩, or ↩ ⌃↩ Esc while carrying, never shed, and the
/// side switch stands last (#3667). Holding ⇧, ⌥ or ⌘ rewrites
/// them as on the other sides.
extension JumpFooter {
    var desktopsHints: [String] { desktopsEntries.map(\.text) }

    var desktopsEntries: [DesktopsHint] {
        guard let desktops else { return [] }
        let enter = JumpKey.returnKey
        let digit = UInt16(JumpKey.digitRows[0])
        let next = DesktopsHint(text: sideHint(modifiers))
        let digits =
            desktops.digits > 1
            ? "⌘1–\(desktops.digits)" : "⌘1"
        let pick = DesktopsHint(
            text: desktops.selectionPicked
                ? DesktopsText.putBack : DesktopsText.pickUp,
            key: enter,
            chord: .command,
            live: desktops.selectionPickable
        )
        let back = DesktopsHint(
            text: DesktopsText.back,
            key: JumpKey.up,
            chord: .command
        )
        if desktops.isCarrying {
            let carry = [
                DesktopsHint(text: DesktopsText.drop, key: enter),
                DesktopsHint(
                    text: DesktopsText.dropFollow,
                    key: enter,
                    chord: .control
                ),
                DesktopsHint(
                    text: DesktopsText.cancel,
                    key: JumpKey.escapeKey
                ),
            ]
            if desktops.isInside { return carry + [pick, back, next] }
            let drop = DesktopsHint(
                text: DesktopsText.dropDesktop(digits),
                key: digit,
                chord: .command
            )
            return carry + (desktops.digits > 0 ? [drop] : []) + [next]
        }
        let jump = DesktopsHint(text: DesktopsText.jump, key: enter)
        if desktops.isInside {
            let swaps = modifiers.contains(.option)
            let second = DesktopsHint(
                text: swaps ? DesktopsText.swapHere : DesktopsText.moveHere,
                key: enter,
                chord: swaps ? .option : .shift
            )
            return [jump, second, pick, back, next]
        }
        let shifted = modifiers.contains(.shift)
        let desktop = DesktopsHint(
            text: shifted
                ? DesktopsText.moveDesktop("⇧" + digits)
                : DesktopsText.jumpDesktop(digits),
            key: digit,
            chord: shifted ? [.shift, .command] : .command
        )
        let open = DesktopsHint(
            text: DesktopsText.openSpace,
            key: JumpKey.down,
            chord: .command
        )
        let there = DesktopsHint(
            text: DesktopsText.moveThere,
            key: enter,
            chord: .shift
        )
        return [jump, there, open]
            + (desktops.digits > 0 ? [desktop] : []) + [next]
    }

    /// The hints the held keys press, as indices into
    /// `desktopsHints`, the side switch aside (#3667): `JumpKey`
    /// reads the held keys as it reads the hint's own chord, and
    /// the press acts. A bare key lights only as ↩'s pick.
    var desktopsLit: Set<Int> {
        let held = Self.held(modifiers)
        func press(_ key: UInt16, _ chord: NSEvent.ModifierFlags) -> JumpKey? {
            JumpKey.of(
                keyCode: key,
                modifiers: chord,
                scope: .desktops,
                naming: naming
            )
        }
        let entries = desktopsEntries
        return Set(
            entries.indices.filter { index in
                let hint = entries[index]
                guard let key = hint.key, hint.live,
                    !hint.chord.isEmpty || key == JumpKey.returnKey,
                    let named = press(key, hint.chord)
                else { return false }
                return press(key, held) == named
            }
        )
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
