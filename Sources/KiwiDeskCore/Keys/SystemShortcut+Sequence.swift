import Foundation

extension SystemShortcut {
    /// Apple's `AppleSymbolicHotKeys` id and the state macOS
    /// ships when the plist has no entry for it; nil = not a
    /// symbolic hotkey at all — an app accelerator, or a system
    /// chord macOS answers first and never lets go (#1275). Ids
    /// verified against each entry's key parameters (keycode +
    /// modifier mask), 2026-09-01, macOS 26.6.2 — an id names
    /// the FEATURE, so a user who rebinds a system chord drifts
    /// this map's chord half, which is #1098's class, not this
    /// read's. A `switch`, not a table: a new case must not
    /// ship without an answer here (the parity idiom
    /// `localizedName` already uses).
    public var symbolicHotkey: (id: Int, shipsEnabled: Bool)? {
        switch self {
        case .spotlight: return (64, true)
        case .appSwitcher: return nil
        case .quitApp: return nil
        case .closeWindow: return nil
        case .minimize: return nil
        case .hideApp: return nil
        case .forceQuit: return nil
        case .missionControlSpaceLeft: return (79, true)
        case .missionControlSpaceRight: return (81, true)
        case .missionControl: return (32, true)
        case .appWindows: return (33, true)
        case .screenshot: return (28, true)
        case .screenshotSelection: return (30, true)
        case .screenshotTools: return (184, true)
        case .zoomToggle: return (15, false)
        case .zoomIn: return (17, false)
        case .zoomOut: return (19, false)
        case .dockHiding: return (52, true)
        case .finderSearch: return (65, true)
        case .inputSourceNext: return (61, true)
        case .invertColors: return (21, false)
        case .increaseContrast: return (25, false)
        case .decreaseContrast: return (26, false)
        // Ids 118…126 = Desktops 1…9, keycode + control mask
        // read 2026-10-15, macOS 27.0.1 (#2311).
        case .switchToDesktop1, .switchToDesktop2, .switchToDesktop3,
            .switchToDesktop4, .switchToDesktop5, .switchToDesktop6,
            .switchToDesktop7, .switchToDesktop8, .switchToDesktop9:
            return desktopNumber.map { (117 + $0, false) }
        }
    }

    /// Whether macOS answers this shortcut, given its plist
    /// `enabled` bit (nil for no entry): a symbolic hotkey by that
    /// bit or its shipped state, any other always (#1105, #3173).
    public func isAnswered(enabled: Bool?) -> Bool {
        guard let hotkey = symbolicHotkey else { return true }
        return enabled ?? hotkey.shipsEnabled
    }

    /// What an open key sequence does with this shortcut (#3173 ▸
    /// Ruling). A `switch`, so a new case cannot ship without an
    /// answer.
    public var sequenceTier: SequencePassTier {
        switch self {
        case .screenshot, .screenshotSelection, .screenshotTools,
            .zoomToggle, .zoomIn, .zoomOut, .invertColors,
            .increaseContrast, .decreaseContrast, .dockHiding:
            return .staysOpen
        case .spotlight, .finderSearch, .appSwitcher, .forceQuit,
            .missionControl, .appWindows, .missionControlSpaceLeft,
            .missionControlSpaceRight, .inputSourceNext,
            .switchToDesktop1, .switchToDesktop2, .switchToDesktop3,
            .switchToDesktop4, .switchToDesktop5, .switchToDesktop6,
            .switchToDesktop7, .switchToDesktop8, .switchToDesktop9:
            return .closes
        case .quitApp, .closeWindow, .minimize, .hideApp:
            return .swallowed
        }
    }
}

/// How an open key sequence treats a macOS shortcut (#3173 ▸
/// Ruling): one that takes no keyboard passes and leaves the panel
/// up; one that takes the keyboard or moves the user passes and
/// closes the sequence; an app's own menu chord stays swallowed, or
/// it would reach the shielded front app.
public enum SequencePassTier: Sendable, Equatable {
    case staysOpen
    case closes
    case swallowed
}

/// What `com.apple.symbolichotkeys` holds for one hotkey id: whether
/// it is on, and the chord it is bound to; each nil where the plist
/// says nothing.
public struct SymbolicHotkeyEntry: Equatable, Sendable {
    public var enabled: Bool?
    public var combo: KeyCombo?

    public init(enabled: Bool? = nil, combo: KeyCombo? = nil) {
        self.enabled = enabled
        self.combo = combo
    }
}

/// The one reader of `com.apple.symbolichotkeys` (#1105, #3173). A
/// cached reader sees external writes (measured 2026-09-01).
public enum SymbolicHotkeys {
    /// The entry for `id`; nil where the plist has none.
    public static func liveRead(_ id: Int) -> SymbolicHotkeyEntry? {
        guard
            let table = CFPreferencesCopyAppValue(
                "AppleSymbolicHotKeys" as CFString,
                "com.apple.symbolichotkeys" as CFString
            ) as? [String: Any],
            let entry = table["\(id)"] as? [String: Any]
        else { return nil }
        let value = entry["value"] as? [String: Any]
        return SymbolicHotkeyEntry(
            enabled: entry["enabled"] as? Bool,
            combo: (value?["parameters"] as? [Int]).flatMap(chord)
        )
    }

    /// A hotkey's `parameters` — character, key code, modifier mask —
    /// as a chord; nil for a key code macOS writes for none (65535).
    static func chord(_ parameters: [Int]) -> KeyCombo? {
        guard parameters.count >= 3, (0..<0xFFFF).contains(parameters[1])
        else { return nil }
        let mask = parameters[2]
        let bits: [(Int, HotkeyModifiers)] = [
            (0x2_0000, .shift), (0x4_0000, .control),
            (0x8_0000, .option), (0x10_0000, .command),
        ]
        let modifiers = bits.reduce(into: HotkeyModifiers()) {
            if mask & $1.0 != 0 { $0.insert($1.1) }
        }
        return KeyCombo(keyCode: UInt32(parameters[1]), modifiers: modifiers)
    }
}

extension SystemShortcuts {
    /// Every shortcut macOS answers now, on the chord it answers:
    /// the live symbolic-hotkey chord where the plist has one, else
    /// the map's; one switched off is left out (#3173).
    public static func answered(
        reading read: (Int) -> SymbolicHotkeyEntry?
    ) -> [(combo: KeyCombo, shortcut: SystemShortcut)] {
        map.sorted {
            ($0.key.comboString() ?? "") < ($1.key.comboString() ?? "")
        }
        .compactMap { combo, shortcut in
            let entry = shortcut.symbolicHotkey.flatMap { read($0.id) }
            guard shortcut.isAnswered(enabled: entry?.enabled) else {
                return nil
            }
            return (entry?.combo ?? combo, shortcut)
        }
    }
}

/// The macOS shortcuts an open key sequence lets through (#3173 ▸
/// Ruling), handed to the router with its sequences, read at each
/// arming from `SystemShortcuts.answered`.
struct SequencePassChords: Equatable, Sendable {
    var staysOpen: [KeyCombo] = []
    var closes: [KeyCombo] = []

    static let none = SequencePassChords()

    static func live(
        reading read: (Int) -> SymbolicHotkeyEntry?
    ) -> SequencePassChords {
        of(SystemShortcuts.answered(reading: read))
    }

    static func of(
        _ answered: [(combo: KeyCombo, shortcut: SystemShortcut)]
    ) -> SequencePassChords {
        var chords = SequencePassChords()
        for (chord, shortcut) in answered {
            switch shortcut.sequenceTier {
            case .staysOpen: chords.staysOpen.append(chord)
            case .closes: chords.closes.append(chord)
            case .swallowed: break
            }
        }
        return chords
    }
}
