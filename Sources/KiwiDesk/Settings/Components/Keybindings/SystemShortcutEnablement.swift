import Foundation
import KiwiDeskCore

/// The live half of a system-shortcut conflict verdict (#1105):
/// whether macOS currently ANSWERS a chord `SystemShortcuts.map`
/// records. GUI-boundary on purpose (core-boundaries.md #96;
/// tests.md's injected-seam row) — reached only through
/// `SettingsModel`'s accessors and `readSymbolicHotkey` seam.
enum SystemShortcutEnablement {
    /// Reads one hotkey id's `enabled` bit from
    /// `com.apple.symbolichotkeys`; nil = no plist entry, the
    /// shipped default applies. A cached reader sees external
    /// writes (measured 2026-09-01); the staleness ruling is
    /// `docs/design-decisions.md` ▸ `⌃⌥⌘8` (#1105).
    static func liveRead(_ id: Int) -> Bool? {
        guard
            let table = CFPreferencesCopyAppValue(
                "AppleSymbolicHotKeys" as CFString,
                "com.apple.symbolichotkeys" as CFString
            ) as? [String: Any],
            let entry = table["\(id)"] as? [String: Any],
            let enabled = entry["enabled"] as? Bool
        else { return nil }
        return enabled
    }

    /// System shortcuts the machine currently has switched OFF —
    /// what `KeybindingConflicts.actionable` drops. A chord with
    /// no symbolic-hotkey id (⌘Q, ⌘Tab, …) cannot be disabled.
    static func disabled(
        reading read: (Int) -> Bool?
    ) -> Set<SystemShortcut> {
        Set(
            SystemShortcut.allCases.filter { shortcut in
                guard
                    let entry = shortcut.symbolicHotkey
                else { return false }
                return !(read(entry.id) ?? entry.shipsEnabled)
            }
        )
    }
}

extension SystemShortcut {
    /// Apple's `AppleSymbolicHotKeys` id and the state macOS
    /// ships when the plist has no entry for it; nil = not a
    /// symbolic hotkey at all — an app accelerator or a system
    /// chord whose press precedence is UNMEASURED (#1126). Ids
    /// verified against each entry's key parameters (keycode +
    /// modifier mask), 2026-09-01, macOS 26.6.2 — an id names
    /// the FEATURE, so a user who rebinds a system chord drifts
    /// this map's chord half, which is #1098's class, not this
    /// read's. A `switch`, not a table: a new case must not
    /// ship without an answer here (the parity idiom
    /// `localizedName` already uses).
    var symbolicHotkey: (id: Int, shipsEnabled: Bool)? {
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
        }
    }
}
