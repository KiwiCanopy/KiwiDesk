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
        SymbolicHotkeys.liveRead(id)?.enabled
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
    /// A chord every app's own menus carry (Close, Quit, Hide,
    /// Minimize). KiwiDesk WINS it — measured on ⌘W and ⌘P
    /// (#1126, #1075) — so the cost is every app's, not the
    /// row's. False for a symbolic hotkey and for the two
    /// system-level chords (⌘Tab, ⌥⌘Esc), which macOS answers
    /// first (#1275). A `switch` for the parity idiom's reason;
    /// that it never overlaps `symbolicHotkey` is held by
    /// `ConflictSeverityTests` ▸ `classesArePartitioned`, since
    /// `of` asks this first and an overlap would make a live
    /// symbolic hotkey read `.shadowsApps`, as if it worked.
    var isUniversalAccelerator: Bool {
        switch self {
        case .closeWindow, .quitApp, .hideApp, .minimize:
            return true
        case .spotlight, .appSwitcher, .forceQuit,
            .missionControlSpaceLeft, .missionControlSpaceRight,
            .missionControl, .appWindows, .screenshot,
            .screenshotSelection, .screenshotTools, .zoomToggle,
            .zoomIn, .zoomOut, .dockHiding, .finderSearch,
            .inputSourceNext, .invertColors, .increaseContrast,
            .decreaseContrast, .switchToDesktop1, .switchToDesktop2,
            .switchToDesktop3, .switchToDesktop4, .switchToDesktop5,
            .switchToDesktop6, .switchToDesktop7, .switchToDesktop8,
            .switchToDesktop9:
            return false
        }
    }
}
