import AppKit
import KiwiDeskCore

/// What a key press means inside Jump to window (#1875 ▸ Ruling —
/// keys; #2229, #2309 for the View side's): fixed, with Lua's
/// alternatives to the navigation keys beside them (#2600). Pure,
/// so every chord is testable without a panel. A press this
/// answers nil for goes to the search field as typing.
enum JumpKey: Equatable {
    /// ↑ / ↓: one row (#2897).
    case step(Int)
    /// Page Up / Page Down: one page.
    case page(Int)
    /// ↩ (Jump) or ⇧↩ (Move here).
    case pick(moveHere: Bool)
    /// ⌥↩ or ⇧⌥↩ on Windows: Swap here (#2885), so ⇧ never
    /// means "there".
    case swapHere
    /// ⌘1–9 or ⇧⌘1–9: the result at that 0-based index.
    case quick(Int, moveHere: Bool)
    /// ⌥⌘1–9 or ⇧⌥⌘1–9 on Windows: Swap here on that result
    /// (#2885, amending Ruling 1).
    case quickSwap(Int)
    /// A Windows ↩ chord `JumpPick.of` picks nothing for: the
    /// panel keeps it and beeps, as a field does a key it cannot
    /// use — never a refusal (#2931).
    case dead
    /// Esc: clears a query, then closes.
    case escape
    /// ⇥ (forward) or ⇧⇥ (back): the next side, wrapping, with
    /// the query cleared.
    case stepScope(forward: Bool)
    /// ← / → in Layouts and Desktops, and on Windows' app strip,
    /// typed or not: one tile (#2897, #3135).
    case side(Int)
    /// ⌘S in Layouts: Keep in Profile.
    case keep
    /// ⌘, in Layouts or Shortcuts: that side's Settings page —
    /// Layout Defaults, or Shortcuts & Gestures.
    case settings
    /// Tab with ⌃, or with ⌥ off the Windows side, stays in the
    /// field.
    case swallow
    /// ⌘↓ on Desktops: open the selected Space (#1229).
    case openSpace
    /// ⌘↑ on Desktops: back to the places.
    case leaveSpace
    /// ⌘↩ on Desktops: pick the window up, or put it back.
    case pickUp
    /// ⌃↩ on Desktops: the move or the drop, and follow.
    case follow

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
        scope: JumpScope = .windows,
        naming: Bool,
        keys: KiwiHubKeys = KiwiHubKeys(),
        back: KeyCombo? = nil
    ) -> JumpKey? {
        let held = modifiers.intersection(
            [.shift, .command, .option, .control]
        )
        let plain = held.isEmpty
        // A field naming a profile keeps every key but ↩, Esc and
        // ⇥, so the caret moves through the name (#2359).
        if naming {
            return namingKey(keyCode, held)
        }
        if scope == .view, let key = layouts(keyCode, held) {
            return key
        }
        if scope == .desktops, let key = desktops(keyCode, held) {
            return key
        }
        // The last-app opener's own key with ⇧ steps the strip
        // back, as ⇧⌘⇥ does macOS's switcher; ahead of every key
        // a Lua alternative or ⇥ could shadow it with (#3135).
        if scope == .windows, let back,
            combo(keyCode, held) == back
        {
            return .side(-1)
        }
        // ← → walk the strip, never the caret, while a query is
        // typed too (#3135 ▸ Amendment).
        if scope == .windows,
            keyCode == left || keyCode == right,
            held.subtracting(.shift).isEmpty
        {
            return .side(keyCode == left ? -1 : 1)
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
            // On Windows ↩ picks what a click picks (#2931).
            guard scope == .windows else {
                guard held.subtracting(.shift).isEmpty else {
                    return nil
                }
                return .pick(moveHere: held.contains(.shift))
            }
            switch JumpPick.of(held) {
            case .jump: return .pick(moveHere: false)
            case .moveHere: return .pick(moveHere: true)
            case .swapHere: return .swapHere
            case nil: return .dead
            }
        default:
            // A Lua alternative is read after every built-in key,
            // so none can shadow one (#2600).
            return quick(keyCode, held, scope: scope)
                ?? alternative(keyCode, held, scope: scope, keys: keys)
        }
    }

    /// The keys a naming field gives up: ↩ saves, Esc and ⇥ end it.
    private static func namingKey(
        _ keyCode: UInt16,
        _ held: NSEvent.ModifierFlags
    ) -> JumpKey? {
        switch keyCode {
        case returnKey, enter:
            return held.isEmpty ? .pick(moveHere: false) : nil
        case escapeKey:
            return held.isEmpty ? .escape : nil
        case tab:
            return held.subtracting(.shift).isEmpty
                ? .stepScope(forward: !held.contains(.shift))
                : .swallow
        default:
            return nil
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

    /// The Desktops side's own keys (#1229): ← → move as on View,
    /// ⌘↓ ⌘↑ open and leave a Space, and ↩ reads its modifier —
    /// ⇧ a window moves and you stay, ⌥ Swap here, ⌃ and follow,
    /// ⌘ pick up.
    private static func desktops(
        _ keyCode: UInt16,
        _ held: NSEvent.ModifierFlags
    ) -> JumpKey? {
        switch keyCode {
        case left, right:
            guard held.subtracting(.shift).isEmpty else { return nil }
            return .side(keyCode == left ? -1 : 1)
        case up, down:
            guard held == .command else { return nil }
            return keyCode == down ? .openSpace : .leaveSpace
        case returnKey, enter:
            switch held {
            case []: return .pick(moveHere: false)
            case .shift: return .pick(moveHere: true)
            case .option, [.option, .shift]: return .swapHere
            case .control: return .follow
            case .command: return .pickUp
            default: return .dead
            }
        default:
            return nil
        }
    }

    /// The Windows side's back key: the last-app opener's chord
    /// with ⇧ added, as registered (#3135, owner 2026-11-09). None
    /// for no opener, a tap, a chord already holding ⇧, or a bare
    /// ⇥, whose ⇧ form is the previous side.
    static func back(of opener: KeyCombo?) -> KeyCombo? {
        guard let opener, !opener.isTap else { return nil }
        let chord = opener.registered
        guard !chord.modifiers.contains(.shift),
            !(UInt16(chord.keyCode) == tab && chord.modifiers.isEmpty)
        else { return nil }
        return KeyCombo(
            keyCode: chord.keyCode,
            modifiers: chord.modifiers.union(.shift)
        )
    }

    /// Whether the press is `chord`, modifiers exactly.
    static func presses(
        _ chord: KeyCombo,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> Bool {
        let held = modifiers.intersection(
            [.shift, .command, .option, .control]
        )
        return combo(keyCode, held) == chord
    }

    /// Whether the key is a ↩ chord or a ⌘ digit — a pick, the
    /// Desktops side's pick-up and follow, or a dead ↩ chord — so it
    /// reads only the modifiers pressed since the opener (#3168).
    var picks: Bool {
        switch self {
        case .pick, .swapHere, .quick, .quickSwap, .dead, .pickUp,
            .follow:
            true
        default: false
        }
    }

    /// The press as `KiwiHubKeys` spells it.
    private static func combo(
        _ keyCode: UInt16,
        _ held: NSEvent.ModifierFlags
    ) -> KeyCombo {
        var modifiers: HotkeyModifiers = []
        if held.contains(.control) { modifiers.insert(.control) }
        if held.contains(.option) { modifiers.insert(.option) }
        if held.contains(.shift) { modifiers.insert(.shift) }
        if held.contains(.command) { modifiers.insert(.command) }
        return KeyCombo(keyCode: UInt32(keyCode), modifiers: modifiers)
    }

    /// What a Lua alternative does: its built-in key's move. ⇧
    /// previews Move here, so an alternative moves under it too, as
    /// the arrows do. ← and → move in View, Desktops and Windows'
    /// strip; on Shortcuts theirs is typing.
    private static func alternative(
        _ keyCode: UInt16,
        _ held: NSEvent.ModifierFlags,
        scope: JumpScope,
        keys: KiwiHubKeys
    ) -> JumpKey? {
        guard
            let key = keys.key(for: combo(keyCode, held))
                ?? keys.key(for: combo(keyCode, held.subtracting(.shift)))
        else { return nil }
        switch key {
        case .up: return .step(-1)
        case .down: return .step(1)
        case .pageUp: return .page(-1)
        case .pageDown: return .page(1)
        case .left: return sideways(scope) ? .side(-1) : nil
        case .right: return sideways(scope) ? .side(1) : nil
        case .openSpace: return scope == .desktops ? .openSpace : nil
        case .leaveSpace: return scope == .desktops ? .leaveSpace : nil
        case .pickUp: return scope == .desktops ? .pickUp : nil
        case .follow: return scope == .desktops ? .follow : nil
        }
    }

    /// The sides whose ← and → move a selection.
    private static func sideways(_ scope: JumpScope) -> Bool {
        scope == .view || scope == .desktops || scope == .windows
    }

    private static func quick(
        _ keyCode: UInt16,
        _ held: NSEvent.ModifierFlags,
        scope: JumpScope
    ) -> JumpKey? {
        guard held.contains(.command) else { return nil }
        let code = UInt32(keyCode)
        let row = KeypadKeys.digitTwins[code] ?? code
        guard let index = digitRows.firstIndex(of: row) else {
            return nil
        }
        // The digits pick as ↩ does: the one chord table.
        switch JumpPick.of(held) {
        case .jump: return .quick(index, moveHere: false)
        case .moveHere: return .quick(index, moveHere: true)
        case .swapHere: return scope == .windows ? .quickSwap(index) : nil
        case nil: return nil
        }
    }
}

/// What a pick on a Windows row does: ↩ / a click Jump, ⇧ Move
/// here, ⌥ or ⇧⌥ Swap here (#1875, #2885, #2931).
enum JumpPick: Equatable {
    case jump
    case moveHere
    case swapHere

    /// The pick ↩, a click and the ⌘ digits make under
    /// `modifiers`, the one chord table: ⌘ never changes the pick,
    /// and any ⌃ picks nothing — ⌃-click is the secondary click
    /// and ⌃⌥ is kept for a follow (#2885 ▸ Ruling 1; #2931).
    static func of(_ modifiers: NSEvent.ModifierFlags) -> JumpPick? {
        let held = modifiers.intersection([.shift, .option, .control])
        if held.contains(.control) { return nil }
        if held.contains(.option) { return .swapHere }
        return held.contains(.shift) ? .moveHere : .jump
    }
}
