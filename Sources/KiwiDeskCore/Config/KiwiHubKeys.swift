import Carbon.HIToolbox
import Foundation

/// A built-in KiwiHub key a binding stands in for, by the key it
/// mirrors (`kiwihub.set_key`'s first argument, #2600).
public enum KiwiHubKey: String, Sendable, CaseIterable, Equatable {
    case up
    case down
    case pageUp = "page_up"
    case pageDown = "page_down"
    case left
    case right
}

extension KiwiHubKey: APIChoiceType {}

/// Lua's alternatives to KiwiHub's navigation keys (`kiwihub.key`,
/// #2600): app-wide, since a key is the hand's and not the desk's.
/// One chord per built-in key, each the canonical
/// `KeyCombo.comboString()`; nil leaves only the built-in key.
public struct KiwiHubKeys: Sendable, Equatable, Codable {
    public var up: String?
    public var down: String?
    public var pageUp: String?
    public var pageDown: String?
    public var left: String?
    public var right: String?

    private enum CodingKeys: String, CodingKey {
        case up, down, left, right
        case pageUp = "page_up"
        case pageDown = "page_down"
    }

    public init() {}

    private static func path(
        _ key: KiwiHubKey
    ) -> WritableKeyPath<KiwiHubKeys, String?> {
        switch key {
        case .up: return \.up
        case .down: return \.down
        case .pageUp: return \.pageUp
        case .pageDown: return \.pageDown
        case .left: return \.left
        case .right: return \.right
        }
    }

    public subscript(key: KiwiHubKey) -> String? {
        get { self[keyPath: Self.path(key)] }
        set { self[keyPath: Self.path(key)] = newValue }
    }

    /// The built-in key whose alternative `combo` is. A stored
    /// chord the verb would refuse — a file edited by hand — never
    /// answers.
    public func key(for combo: KeyCombo) -> KiwiHubKey? {
        KiwiHubKey.allCases.first { key in
            guard let stored = self[key].flatMap(KeyCombo.parse) else {
                return false
            }
            return stored == combo
                && KiwiHubKeyRefusal.ofChord(stored) == nil
        }
    }
}

/// Why `kiwihub.set_key` refuses a chord (#2600). English, a CLI
/// contract (core-boundaries.md).
public enum KiwiHubKeyRefusal: Equatable, Sendable {
    /// No ⌃ or ⌘: the press would type into the search field,
    /// ⌥ included, which types a character.
    case typesIntoField
    /// The Hyper key, which the panel cannot read.
    case hyper
    /// A key the panel already answers whatever is held.
    case panelKey
    /// The alternative of another built-in key.
    case taken(KiwiHubKey)

    public var message: String {
        switch self {
        case .typesIntoField:
            return "a KiwiHub key needs ctrl or cmd"
        case .hyper:
            return "KiwiHub cannot read hyper"
        case .panelKey:
            return "KiwiHub already uses that key"
        case .taken(let other):
            return "already the key for \(other.rawValue)"
        }
    }

    /// The refusal for `combo` as `key`'s alternative in `keys`,
    /// or nil where the panel can take it.
    public static func of(
        _ combo: KeyCombo,
        as key: KiwiHubKey,
        in keys: KiwiHubKeys
    ) -> KiwiHubKeyRefusal? {
        if let refusal = ofChord(combo) { return refusal }
        if let other = keys.key(for: combo), other != key {
            return .taken(other)
        }
        return nil
    }

    /// The refusal the chord earns on its own, whatever else is set.
    static func ofChord(_ combo: KeyCombo) -> KiwiHubKeyRefusal? {
        if combo.modifiers.contains(.hyper) { return .hyper }
        if combo.modifiers.isDisjoint(with: [.control, .command]) {
            return .typesIntoField
        }
        return panelKeeps(combo) ? .panelKey : nil
    }

    /// The keys the panel answers itself: ↩ Esc ⇥ and the arrows
    /// and page keys under any modifier, the ⌘ digits, and the ⌘
    /// chords it keeps (⌘S ⌘, ⌘W) or hands to the field's Edit
    /// menu. Matched by key code, as the panel's own ⌘S is;
    /// `KiwiHubKeyParityTests` holds it to the panel.
    static func panelKeeps(_ combo: KeyCombo) -> Bool {
        let code = Int(combo.keyCode)
        if anyModifier.contains(code) { return true }
        guard combo.modifiers.contains(.command) else { return false }
        let row = KeypadKeys.rowTwin(of: combo.keyCode) ?? combo.keyCode
        let digit = KeypadKeys.digits.contains { $0.row == row }
        return digit || commandKeeps.contains(code)
    }

    private static let anyModifier: Set<Int> = [
        kVK_Return, kVK_ANSI_KeypadEnter, kVK_Escape, kVK_Tab,
        kVK_UpArrow, kVK_DownArrow, kVK_LeftArrow, kVK_RightArrow,
        kVK_PageUp, kVK_PageDown,
    ]

    private static let commandKeeps: Set<Int> = [
        kVK_ANSI_S, kVK_ANSI_Comma, kVK_ANSI_W, kVK_ANSI_A,
        kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_X, kVK_ANSI_Z,
    ]
}
