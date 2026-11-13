import Foundation

/// A modifier tap held in a chord's place (#1872): `rcmd` taps
/// Right ⌘ once, `cmd` either ⌘ once (#3259), `cmd+cmd` taps either
/// ⌘ twice (the same key both times), `ropt+ropt` taps Right ⌥
/// twice. Stored in the chord's own string and type, so every row
/// and Lua take one alike; its key code is a sentinel no keyboard
/// sends, so Carbon is never asked for it
/// (`docs/design-decisions.md` ▸ *A modifier tap is one binding
/// kind*).
extension KeyCombo {
    /// The sentinel key codes, one per tap count.
    static let tapOnceCode: UInt32 = 0x1_0001
    static let tapTwiceCode: UInt32 = 0x1_0002

    /// A tap of `kind` pressed `count` times (1 or 2) on `side`,
    /// nil for either side; nil where the rules refuse it.
    public static func tap(
        _ kind: ModifierKind,
        side: ModifierSide?,
        count: Int
    ) -> KeyCombo? {
        guard count == 1 || count == 2 else { return nil }
        var modifiers = kind.plain
        if let side { modifiers.insert(.side(side, of: kind)) }
        return KeyCombo(
            keyCode: count == 1 ? tapOnceCode : tapTwiceCode,
            modifiers: modifiers
        )
    }

    /// 1 or 2 for a modifier tap, nil for a chord.
    public var tapCount: Int? {
        switch keyCode {
        case Self.tapOnceCode: 1
        case Self.tapTwiceCode: 2
        default: nil
        }
    }

    public var isTap: Bool { tapCount != nil }

    /// The tapped modifier, nil for a chord.
    public var tapKind: ModifierKind? {
        guard isTap else { return nil }
        return ModifierKind.allCases.first {
            modifiers.contains($0.plain)
        }
    }

    /// `parts` as a tap's spelling: one token alone, or the same
    /// token twice; nil for anything else.
    static func parseTap(_ parts: [String]) -> KeyCombo? {
        guard parts.count == 1 || parts.count == 2,
            Set(parts).count == 1,
            let (kind, side) = tapToken(parts[0])
        else { return nil }
        return tap(kind, side: side, count: parts.count)
    }

    private static func tapToken(
        _ part: String
    ) -> (ModifierKind, ModifierSide?)? {
        if let kind = plainKinds[part] { return (kind, nil) }
        if let (kind, side) = sideTokens[part] { return (kind, side) }
        return nil
    }

    /// A tap's canonical spelling, which `parse` round-trips.
    var tapString: String? {
        guard let count = tapCount, let kind = tapKind else {
            return nil
        }
        let short: String =
            switch kind {
            case .control: "ctrl"
            case .option: "opt"
            case .shift: "shift"
            case .command: "cmd"
            }
        let token: String =
            switch modifiers.side(of: kind) {
            case .left: "l" + short
            case .right: "r" + short
            case nil: short
            }
        return Array(repeating: token, count: count)
            .joined(separator: "+")
    }
}
