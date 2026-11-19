import Foundation

/// Which door hears a row's press first (#3311): a Carbon hotkey, or
/// the keyboard tap, whose swallow comes before macOS's own shortcuts.
/// `KeyboardTapArming` decides which rows the tap answers.
public enum PressPath: Sendable, Equatable {
    case carbon
    case keyboardTap
}

/// Who answers a press of a macOS shortcut's chord that a KiwiDesk
/// row holds (#3504): macOS alone (the row never fires), KiwiDesk
/// alone (macOS loses the shortcut), or both, the row firing and
/// macOS still running its shortcut.
public enum PressAnswer: Sendable, Equatable {
    case macOS
    case kiwiDesk
    case both
}

extension SystemShortcut {
    /// Who answers a KiwiDesk row on this shortcut's chord, its press
    /// coming through `path` while macOS has the shortcut on — the one
    /// rule a row, a leader and a step key are read by (#3311). A case
    /// leaves `.macOS` only on a path measured to; ⌘⇧3 and ⌃← are
    /// mirrors of their measured twins. The measurements are
    /// `docs/design-decisions.md` ▸ the #3239, #3311, #3331 and #3504
    /// amendments.
    public func answer(on path: PressPath) -> PressAnswer {
        switch self {
        case .inputSourceNext:
            return .kiwiDesk
        // A Carbon hotkey on ⌃Space fires and macOS still switches,
        // where one on ⌃⌥Space does not (#3504, both measured by hand
        // with a source poller).
        case .inputSourcePrevious:
            return path == .keyboardTap ? .kiwiDesk : .both
        case .spotlight, .appSwitcher, .missionControlSpaceLeft,
            .missionControlSpaceRight, .missionControl, .appWindows,
            .screenshot, .screenshotSelection, .screenshotTools,
            .dockHiding, .finderSearch:
            return path == .keyboardTap ? .kiwiDesk : .macOS
        // The clipboard screenshots are unmeasured on every path
        // (#3382), so macOS keeps them.
        case .screenshotToClipboard, .screenshotSelectionToClipboard:
            return .macOS
        case .forceQuit, .zoomToggle, .zoomIn, .zoomOut, .invertColors,
            .increaseContrast, .decreaseContrast, .switchToDesktop1,
            .switchToDesktop2, .switchToDesktop3, .switchToDesktop4,
            .switchToDesktop5, .switchToDesktop6, .switchToDesktop7,
            .switchToDesktop8, .switchToDesktop9:
            return .macOS
        case .quitApp, .closeWindow, .minimize, .hideApp:
            return .macOS
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
