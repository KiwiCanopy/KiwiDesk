import Foundation

/// Reserved macOS shortcuts as cases, never display strings
/// (#96): `L()` is `@MainActor` while this file is actor-free, so
/// Core names the shortcut and the GUI localizes it. The GUI's
/// `localizedName` switch is exhaustive — a new case cannot ship
/// without a string; the compiler is the parity guard (§5,
/// `KeybindingCatalog`).
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
    // ⌥⌘ family (#1075). The Zoom trio is Accessibility-gated —
    // enablement lives in the GUI's `SystemShortcutEnablement`
    // (#1105) — and while one is ON, macOS answers the press
    // before the binding hears it (#1126; the registration
    // itself is accepted).
    case zoomToggle
    case zoomIn
    case zoomOut
    case dockHiding
    case finderSearch
    // The one ⌃⌥ chord macOS reserves (#1094): "quiet" (#270)
    // is not "empty". `SizeLayerSeedTests` checks SEEDED rows
    // only, and only those its fixture generates — widen the
    // fixture rather than trusting its green; a chord nothing
    // seeds is invisible to every guard.
    case inputSourceNext
    // ⌃⌥⌘ trio (#1094 review): Accessibility-gated like the
    // Zoom trio — the shape a reputation-based list misses.
    // `⌃⌥⌘8` is a SEEDED row, so this makes an existing
    // collision visible.
    case invertColors
    case increaseContrast
    case decreaseContrast
}

/// System shortcut conflict mappings (`KeybindingConflicts`).
public enum SystemShortcuts {
    /// Known system shortcuts keyed by parsed key combination.
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
        ("control+option+space", .inputSourceNext),
        ("control+option+command+8", .invertColors),
        ("control+option+command+.", .increaseContrast),
        ("control+option+command+,", .decreaseContrast),
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
