import AppKit
import KiwiDeskCore

/// What a key press means inside Jump to window (#1875 ▸ Ruling —
/// keys; #2229, #2309 for the View side's): fixed, never rebindable.
/// Pure, so every chord is testable without a panel. A press this
/// answers nil for goes to the search field as typing.
enum JumpKey: Equatable {
    /// ↑ / ↓: one row, never wrapping.
    case step(Int)
    /// Page Up / Page Down: one page.
    case page(Int)
    /// ↩ (Jump) or ⇧↩ (Move here).
    case pick(moveHere: Bool)
    /// ⌘1–9 or ⇧⌘1–9: the result at that 0-based index.
    case quick(Int, moveHere: Bool)
    /// Esc: clears a query, then closes.
    case escape
    /// ⇥ (forward) or ⇧⇥ (back): the next side, wrapping, with
    /// the query cleared.
    case stepScope(forward: Bool)
    /// ← / → in Layouts: one tile, never wrapping.
    case side(Int)
    /// ⌘S in Layouts: Keep in Profile.
    case keep
    /// ⌘, in Layouts or Shortcuts: that side's Settings page —
    /// Layout Defaults, or Shortcuts & Gestures.
    case settings
    /// Tab with ⌃ or ⌥ stays in the field.
    case swallow

    private static let up: UInt16 = 126
    private static let down: UInt16 = 125
    private static let pageUp: UInt16 = 116
    private static let pageDown: UInt16 = 121
    static let returnKey: UInt16 = 36
    private static let enter: UInt16 = 76
    private static let escapeKey: UInt16 = 53
    private static let tab: UInt16 = 48
    private static let left: UInt16 = 123
    private static let right: UInt16 = 124
    private static let sKey: UInt16 = 1
    private static let comma: UInt16 = 43

    /// The number-row codes of 1–9, in order; a keypad digit is
    /// its row twin (`KeypadKeys`, #1074).
    static let digitRows: [UInt32] = KeypadKeys.digits
        .filter { $0.legend != "0" }
        .sorted { $0.legend < $1.legend }
        .map(\.row)

    static func of(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        scope: JumpScope = .windows
    ) -> JumpKey? {
        let held = modifiers.intersection(
            [.shift, .command, .option, .control]
        )
        let plain = held.isEmpty
        if scope == .view, let key = layouts(keyCode, held) {
            return key
        }
        if scope != .windows, keyCode == comma, held == .command {
            return .settings
        }
        switch keyCode {
        case tab:
            return held.subtracting(.shift).isEmpty
                ? .stepScope(forward: !held.contains(.shift))
                : .swallow
        case escapeKey:
            return plain ? .escape : nil
        // Whatever is held: ⇧ previews Move here and ⌘ the numbers,
        // and the list must still move under either.
        case up, down:
            return .step(keyCode == up ? -1 : 1)
        case pageUp, pageDown:
            return .page(keyCode == pageUp ? -1 : 1)
        case returnKey, enter:
            guard held.subtracting(.shift).isEmpty else { return nil }
            return .pick(moveHere: held.contains(.shift))
        default:
            return quick(keyCode, held)
        }
    }

    /// The View side's own keys: ← → move along a line even while
    /// the field has focus (owner ruling, #2229), ⌘S keeps.
    private static func layouts(
        _ keyCode: UInt16,
        _ held: NSEvent.ModifierFlags
    ) -> JumpKey? {
        switch keyCode {
        case left, right:
            guard held.subtracting(.shift).isEmpty else { return nil }
            return .side(keyCode == left ? -1 : 1)
        case sKey:
            return held == .command ? .keep : nil
        default:
            return nil
        }
    }

    private static func quick(
        _ keyCode: UInt16,
        _ held: NSEvent.ModifierFlags
    ) -> JumpKey? {
        guard held.contains(.command),
            held.subtracting([.command, .shift]).isEmpty
        else { return nil }
        let code = UInt32(keyCode)
        let row = KeypadKeys.digitTwins[code] ?? code
        guard let index = digitRows.firstIndex(of: row) else {
            return nil
        }
        return .quick(index, moveHere: held.contains(.shift))
    }
}
