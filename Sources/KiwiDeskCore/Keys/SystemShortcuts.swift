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
    // The one ⌃⌥ chord macOS reserves (#1094). ⌃⌥ is otherwise
    // the quiet base #270 chose it for — measured with NO
    // bindings across sixteen installed apps (2026-08-29) — but
    // "quiet" is not "empty", and this entry is the difference.
    // `SizeLayerSeedTests.noSeededRowShadowsTheSystem` checks
    // SEEDED rows only — and only those its fixture generates,
    // so widen that fixture rather than trusting its green. A
    // chord nothing seeds is invisible to every guard: before
    // this case, a user binding ⌃⌥space themselves got no
    // warning and a silently dead hotkey.
    // Measured from `com.apple.symbolichotkeys` id 61 ("Select
    // next source in Input menu", enabled) on macOS 26.6.
    case inputSourceNext
    // The ⌃⌥⌘ family (#1094 review). Measured from
    // `com.apple.symbolichotkeys` ids 21/25/26 on macOS 26.6,
    // 2026-08-29 — all three ship DISABLED, gated on
    // Accessibility, which is exactly the shape that made the
    // ⌥⌘ Zoom trio invisible to a reputation-based list one rung
    // up this ladder. `⌃⌥⌘8` is a SEEDED row (move-to-space-8
    // and follow), so this entry makes an existing collision
    // visible rather than introducing one.
    case invertColors
    case increaseContrast
    case decreaseContrast
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
        ("control+option+space", .inputSourceNext),
        ("control+option+command+8", .invertColors),
        ("control+option+command+.", .increaseContrast),
        ("control+option+command+,", .decreaseContrast),
    ])

    /// Chords macOS reserves but ships DISABLED, measured from
    /// `com.apple.symbolichotkeys` on macOS 26.6 (2026-08-29):
    /// the Zoom trio and the Accessibility display trio are all
    /// `enabled = false` out of the box.
    ///
    /// They stay in `map` — the board draws them, and a chord
    /// the user has switched ON really does take the key — but
    /// `KeybindingConflicts` does not raise them, because the
    /// register knows the CHORD and not whether macOS currently
    /// answers it. Raising them anyway made a seeded row
    /// (`⌃⌥⌘8`, tier 3's move-to-space-8) carry a standing
    /// conflict shout on every install with 8+ Desktops, for a
    /// chord that works for everyone who has not turned Invert
    /// Colors on.
    ///
    /// This is a STOPGAP and it errs the other way: a user who
    /// HAS enabled one of these gets no warning, which is the
    /// state that shipped. It ends when the conflict surface
    /// reads the live `enabled` flag and can tell the two apart
    /// — filed for that, and this set goes away with it.
    public static let shipsDisabled: Set<SystemShortcut> = [
        .zoomToggle, .zoomIn, .zoomOut,
        .invertColors, .increaseContrast, .decreaseContrast,
    ]

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
