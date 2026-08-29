import Foundation

/// A reserved macOS shortcut, as a **case rather than a display
/// string** (#96). `L()` is `@MainActor` — it drives SwiftUI and
/// publishes — while this file is actor-free pure logic exercised
/// by non-`@MainActor` tests (§2.6), so Core names the shortcut
/// and the GUI localizes it at its own boundary. That is the same
/// canonical → label split `KeybindingCatalog` already uses, and
/// it keeps these names out of English-only limbo.
///
/// The GUI's `localizedName` switch is exhaustive, so **adding a
/// case here is a compile error until it has a string** — the
/// parity guard is the compiler, not a hand-listed test that
/// could itself be forgotten (§5).
public enum SystemShortcut: Sendable, CaseIterable {
    case spotlight
    case appSwitcher
    case quitApp
    case closeWindow
    case minimize
    case hideApp
    case forceQuit
    case missionControlSpaceLeft
    case missionControlSpaceRight
    case missionControl
    case appWindows
    case screenshot
    case screenshotSelection
    case screenshotTools
    // The ⌥⌘ family (#1075). Added when size took that base:
    // the map had no ⌥⌘ entry at all, so nothing warned a user
    // binding one and the board drew them free. Zoom's three are
    // gated on Accessibility ▸ Zoom ▸ "Use keyboard shortcuts to
    // zoom" and ship OFF, but a gated shortcut still wins when
    // it is on, and `RegisterEventHotKey` fails silently.
    // Measured from `com.apple.symbolichotkeys` (ids 15/19/17,
    // 52, 65) on macOS 26.6, 2026-08-28.
    case zoomToggle
    case zoomIn
    case zoomOut
    case dockHiding
    case finderSearch
}

/// Reserved macOS shortcuts KiwiDesk shouldn't shadow, used by
/// `KeybindingConflicts` to flag rows that clash with the
/// system rather than another row.
public enum SystemShortcuts {
    /// Known system shortcuts keyed by the parsed combo.
    public static let map: [KeyCombo: SystemShortcut] = build([
        ("command+space", .spotlight),
        ("command+tab", .appSwitcher),
        ("command+q", .quitApp),
        ("command+w", .closeWindow),
        ("command+m", .minimize),
        ("command+h", .hideApp),
        ("command+option+esc", .forceQuit),
        ("control+left", .missionControlSpaceLeft),
        ("control+right", .missionControlSpaceRight),
        ("control+up", .missionControl),
        ("control+down", .appWindows),
        ("command+shift+3", .screenshot),
        ("command+shift+4", .screenshotSelection),
        ("command+shift+5", .screenshotTools),
        ("option+command+8", .zoomToggle),
        ("option+command+equal", .zoomIn),
        ("option+command+minus", .zoomOut),
        ("option+command+d", .dockHiding),
        ("option+command+space", .finderSearch),
    ])

    private static func build(
        _ entries: [(String, SystemShortcut)]
    ) -> [KeyCombo: SystemShortcut] {
        var map: [KeyCombo: SystemShortcut] = [:]
        for (combo, shortcut) in entries {
            if let parsed = KeyCombo.parse(combo) {
                map[parsed] = shortcut
            }
        }
        return map
    }
}
