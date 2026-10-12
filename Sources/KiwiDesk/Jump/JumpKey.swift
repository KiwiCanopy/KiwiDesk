import AppKit
import KiwiDeskCore

/// What a key press means inside Jump to window (#1875 ▸ Ruling —
/// keys): fixed, never rebindable. Pure, so every chord is
/// testable without a panel. A press this answers nil for goes to
/// the search field as typing.
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
    /// Tab and its variants stay in the field.
    case swallow

    private static let up: UInt16 = 126
    private static let down: UInt16 = 125
    private static let pageUp: UInt16 = 116
    private static let pageDown: UInt16 = 121
    private static let returnKey: UInt16 = 36
    private static let enter: UInt16 = 76
    private static let escapeKey: UInt16 = 53
    private static let tab: UInt16 = 48

    /// The number-row codes of 1–9, in order; a keypad digit is
    /// its row twin (`KeypadKeys`, #1074).
    private static let digitRows: [UInt32] = KeypadKeys.digits
        .filter { $0.legend != "0" }
        .sorted { $0.legend < $1.legend }
        .map(\.row)

    static func of(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> JumpKey? {
        let held = modifiers.intersection(
            [.shift, .command, .option, .control]
        )
        let plain = held.isEmpty
        switch keyCode {
        case tab:
            return .swallow
        case escapeKey:
            return plain ? .escape : nil
        case up, down:
            return plain ? .step(keyCode == up ? -1 : 1) : nil
        case pageUp, pageDown:
            return plain ? .page(keyCode == pageUp ? -1 : 1) : nil
        case returnKey, enter:
            guard held.subtracting(.shift).isEmpty else { return nil }
            return .pick(moveHere: held.contains(.shift))
        default:
            return quick(keyCode, held)
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
