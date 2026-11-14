import Foundation

/// Which door hears a row's press first (#3311): a Carbon hotkey, or
/// the keyboard tap, whose swallow comes before macOS's own shortcuts.
/// `KeyboardTapArming` decides which rows the tap answers.
public enum PressPath: Sendable, Equatable {
    case carbon
    case keyboardTap
}

extension SystemShortcut {
    /// Whether a KiwiDesk row on this shortcut's chord takes it from
    /// macOS when its press comes through `path` — the one rule a row,
    /// a leader and a step key are read by (#3311). Measured on macOS
    /// 27.2, 2026-11-14: the keyboard tap took every chord a posted
    /// press fires (Spotlight, Finder search, Mission Control, App
    /// windows, the screenshot tools, a Space switch, ⌘Tab, Dock
    /// hiding, the input source), and Carbon only ⌃⌥Space (#3239);
    /// Carbon loses the rest (#1126, #1275). A posted ⌥⌘Esc opens no
    /// Force Quit, so it stays macOS's on both paths. An app's menu
    /// chord is the apps', never macOS's (`isUniversalAccelerator`).
    public func losesToKiwiDesk(on path: PressPath) -> Bool {
        switch self {
        case .inputSourceNext:
            return true
        case .forceQuit, .quitApp, .closeWindow, .minimize, .hideApp:
            return false
        case .spotlight, .appSwitcher, .missionControlSpaceLeft,
            .missionControlSpaceRight, .missionControl, .appWindows,
            .screenshot, .screenshotSelection, .screenshotTools,
            .zoomToggle, .zoomIn, .zoomOut, .dockHiding, .finderSearch,
            .invertColors, .increaseContrast, .decreaseContrast,
            .switchToDesktop1, .switchToDesktop2, .switchToDesktop3,
            .switchToDesktop4, .switchToDesktop5, .switchToDesktop6,
            .switchToDesktop7, .switchToDesktop8, .switchToDesktop9:
            return path == .keyboardTap
        }
    }
}

extension KeybindingConflicts {
    /// The door `binding`'s press comes through, read from the same
    /// sort the manager arms from (`KeyboardTapArming`): a leader or
    /// a row `.sides` answers is the tap's, every other row Carbon's.
    static func pressPath(
        of binding: KeyBinding,
        among rivals: [(KeyBinding, KeyCombo)],
        distinguishingSides: Bool
    ) -> PressPath {
        let arming = KeyboardTapArming(
            rows: rivals.filter { !$0.0.isSequence }.map { ($0.1, $0.0) },
            leaders: rivals.filter(\.0.isSequence).map { ($0.1, $0.0) },
            distinguishingSides: distinguishingSides
        )
        let tapped = KeyboardTapConsumer.allCases.contains { consumer in
            arming.rows(for: consumer).contains {
                switch $0.1 {
                case .row(let row), .leader(_, let row):
                    return row.id == binding.id
                }
            }
        }
        return tapped ? .keyboardTap : .carbon
    }
}
