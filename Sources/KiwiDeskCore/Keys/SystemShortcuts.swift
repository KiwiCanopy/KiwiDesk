import Foundation

/// Reserved macOS system shortcut identifiers (#96, `KeybindingCatalog`).
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
    // ⌥⌘ zoom & system shortcuts (`com.apple.symbolichotkeys`, #1075).
    case zoomToggle
    case zoomIn
    case zoomOut
    case dockHiding
    case finderSearch
    // ⌃⌥ input source shortcut (`SizeLayerSeedTests`, #270, #1094).
    case inputSourceNext
    // ⌃⌥⌘ accessibility contrast shortcuts (#1094 review).
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

extension SystemShortcut {
    /// Whether shortcut is shipped disabled by default
    /// (`com.apple.symbolichotkeys`, #1105).
    public var shipsDisabled: Bool {
        switch self {
        case .zoomToggle, .zoomIn, .zoomOut,
            .invertColors, .increaseContrast, .decreaseContrast:
            return true
        case .spotlight, .appSwitcher, .quitApp, .closeWindow,
            .minimize, .hideApp, .forceQuit,
            .missionControlSpaceLeft, .missionControlSpaceRight,
            .missionControl, .appWindows, .screenshot,
            .screenshotSelection, .screenshotTools, .dockHiding,
            .finderSearch, .inputSourceNext:
            return false
        }
    }
}
