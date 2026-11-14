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
    /// a leader and a step key are read by (#3311). A case is true
    /// only on a path measured to win it, ⌘⇧3 and ⌃← as mirrors of
    /// their measured twins; the measurement is `docs/design-decisions.md`
    /// ▸ the #3311 amendment.
    public func losesToKiwiDesk(on path: PressPath) -> Bool {
        switch self {
        case .inputSourceNext:
            return true
        case .spotlight, .appSwitcher, .missionControlSpaceLeft,
            .missionControlSpaceRight, .missionControl, .appWindows,
            .screenshot, .screenshotSelection, .screenshotTools,
            .dockHiding, .finderSearch:
            return path == .keyboardTap
        case .forceQuit, .zoomToggle, .zoomIn, .zoomOut, .invertColors,
            .increaseContrast, .decreaseContrast, .switchToDesktop1,
            .switchToDesktop2, .switchToDesktop3, .switchToDesktop4,
            .switchToDesktop5, .switchToDesktop6, .switchToDesktop7,
            .switchToDesktop8, .switchToDesktop9:
            return false
        case .quitApp, .closeWindow, .minimize, .hideApp:
            return false
        }
    }
}

extension KeybindingConflicts {
    /// The sort the manager arms from (`KeyboardTapArming`), over a
    /// layer's parsed rows: a sequence row is a leader, every other
    /// row a press row. The one adapter the conflict readers share.
    static func tapArming(
        over rivals: [(KeyBinding, KeyCombo)],
        distinguishingSides: Bool
    ) -> KeyboardTapArming<KeyBinding, KeyBinding> {
        KeyboardTapArming(
            rows: rivals.filter { !$0.0.isSequence }.map { ($0.1, $0.0) },
            leaders: rivals.filter(\.0.isSequence).map { ($0.1, $0.0) },
            distinguishingSides: distinguishingSides
        )
    }

    /// The door `binding`'s press comes through while the tap is
    /// armed: a leader or a row `.sides` answers is the tap's, every
    /// other row Carbon's. A refused tap hands sided rows back to
    /// Carbon; that case is `activationFailures`' to narrate.
    static func pressPath(
        of binding: KeyBinding,
        among rivals: [(KeyBinding, KeyCombo)],
        distinguishingSides: Bool
    ) -> PressPath {
        let arming = tapArming(
            over: rivals,
            distinguishingSides: distinguishingSides
        )
        let tapped = KeyboardTapConsumer.allCases.contains { consumer in
            arming.rows(for: consumer).contains {
                $0.1.binding.id == binding.id
            }
        }
        return tapped ? .keyboardTap : .carbon
    }
}
