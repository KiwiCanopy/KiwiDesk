import KiwiDeskCore
import SwiftUI

/// Item 16's crash-supervision row, which turn 14b places
/// first among Advanced's five.
///
/// Its own file because `GeneralSection` crossed AGENTS.md
/// §2.1's 350-line ceiling, and because a destination's
/// widgets belong under `Settings/Components/<area>/` —
/// `gui.md`'s file-layout rule.
extension GeneralSection {
    /// Item 16's second row: crash supervision, the half of the
    /// #576 level that turn 14b puts among Advanced's five.
    ///
    /// **Inert while login is off, and that is a courtesy, not
    /// the guard.** Restarting on crash means the `kiwidesk
    /// service` LaunchAgent, whose `RunAtLoad` and `KeepAlive`
    /// are one indivisible unit — so "restart but do not start at
    /// login" names no reachable state. The refusal lives in
    /// `AutoStartLevel.level(openAtLogin:restartOnCrash:)`, which
    /// discards the flag; `gui.md` bans a grey as the sole gate
    /// on a side effect, and this side effect writes a plist.
    ///
    /// Why-you-cannot is inline (item 19): the caption states the
    /// dependency rather than leaving a dimmed switch unexplained.
    var restartOnCrashRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                L(
                    "general.advanced.restart_on_crash",
                    "Restart if it stops unexpectedly"
                ),
                isOn: restartBinding
            )
            .disabled(!restartEditable)
            if !model.autoStart.level.opensAtLogin {
                Text(
                    L(
                        "general.advanced.restart_on_crash.needs_login",
                        "Needs “Start KiwiDesk when I log in”, "
                            + "because the two are one setting to "
                            + "macOS."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Editable only when the login half is on AND the copy can
    /// register at all — the same unregisterable condition the
    /// login row greys on, since a LaunchAgent needs the stable
    /// `.app` path just as much as the login item does.
    var restartEditable: Bool {
        model.autoStartEditable
            && model.autoStart.level.opensAtLogin
    }

    var restartBinding: Binding<Bool> {
        Binding(
            get: { model.autoStart.level.restartsOnCrash },
            set: { on in
                model.setAutoStart(
                    openAtLogin:
                        model.autoStart.level.opensAtLogin,
                    restartOnCrash: on
                )
            }
        )
    }

}
