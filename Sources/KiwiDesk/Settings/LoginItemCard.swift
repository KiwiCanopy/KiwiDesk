import AppKit
import KiwiDeskCore
import SwiftUI

/// The "Start KiwiDesk when I log in" row (#576, resplit for
/// #678 item 16).
///
/// #576 folded #342's login toggle and the `kiwidesk service`
/// LaunchAgent into ONE 3-level picker, because the two-toggle
/// shape could render *login off + restart on*, which names no
/// reachable state. Turn 14b asks for two rows again — the
/// crash-restart half belongs among Advanced's five — and the
/// constraint moved rather than went away: both rows write
/// through `AutoStartLevel.level(openAtLogin:restartOnCrash:)`,
/// which discards the restart flag when login is off. Read
/// `AutoStartManager`'s header for why that pair is impossible
/// at the OS, and `SettingsModel+AutoStart` for why the status
/// no longer lives in this view.
///
/// A **read-through**, **async** control: it stores no preference,
/// it reads `AutoStartManager.current()` off the main actor on
/// appear and on every `didBecomeActive`, and a change writes
/// through `AutoStartManager.set(_:)` and adopts the state it reads
/// back. launchctl is a blocking spawn, so the read/write happen on
/// a detached task and publish on main; `autoStartLoaded` gates the
/// pending window before the first read lands.
///
/// Core hands us structure (`AutoStartStatus`); the labels and
/// captions are rendered here (#96). The toggle greys (grey, don't
/// hide, #171) when the running copy can't register — a bare
/// binary or a translocated download — which is the shape #342's
/// whole-toggle grey took.
struct LoginItemCard: View {
    @ObservedObject var model: SettingsModel
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        SettingsSection(SettingsCatalog.general.loginItemCard) {
            VStack(alignment: .leading, spacing: 6) {
                DropdownRow(
                    // Card heading is the noun "Login"; the row
                    // carries the verb.
                    label: startLabel,
                    help: startHelp
                ) {
                    // A Toggle, not the #576 Picker: this row now
                    // asks ONE yes/no question, and the second
                    // question (restart on crash) is its own row
                    // among Advanced's five. `gui.md` gives a
                    // toggle the binary case.
                    Toggle("", isOn: loginBinding)
                        .labelsHidden()
                        // Grey the control only, never the row —
                        // the label's `?` stays live because that
                        // help is useful whether or not the
                        // toggle can be driven right now. An
                        // unregisterable copy (bare binary,
                        // translocated download) cannot register
                        // at all, and the caption below names the
                        // fix (#342, #171).
                        .disabled(!model.autoStartEditable)
                }
                confirmation
                caption
            }
        }
        .onAppear { model.refreshAutoStart() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in model.refreshAutoStart() }
    }

    private var startLabel: String {
        L("general.login_item.start", "Start KiwiDesk")
    }

    /// The one field-level `?` (#94): explains all three levels and
    /// is the only place the crash-restart mechanism is named — the
    /// row itself stays a plain label.
    private var startHelp: String {
        L(
            "general.login_item.start_help",
            "Choose when KiwiDesk starts on its own. "
                + "\u{201C}At Login\u{201D} launches it when you sign "
                + "in, so your windows are arranged from the start. "
                + "\u{201C}At Login + Restart on Crash\u{201D} also "
                + "runs a background helper that relaunches KiwiDesk "
                + "if it ever crashes. \u{201C}Never\u{201D} turns "
                + "both off."
        )
    }

    /// Writing a level routes through the facade and adopts the
    /// This row's half of the folded level: does KiwiDesk start
    /// itself at all.
    ///
    /// Writing preserves the OTHER row's answer rather than
    /// clearing it — turning login off and on again must not
    /// silently drop crash-restart — and the fold in
    /// `AutoStartLevel.level(openAtLogin:restartOnCrash:)` is
    /// what makes "off + restart" collapse instead of persisting
    /// as a contradiction.
    ///
    /// The refusal on an unregisterable copy lives in
    /// `SettingsModel.setAutoStart`, not here: the harm is a
    /// filesystem/launchd side effect (a LaunchAgent written
    /// against an ephemeral `.build` or translocated path, which
    /// read-through cannot undo), so it must not depend on a view
    /// having disabled the control.
    private var loginBinding: Binding<Bool> {
        Binding(
            get: { model.autoStart.level.opensAtLogin },
            set: { on in
                model.setAutoStart(
                    openAtLogin: on,
                    restartOnCrash:
                        model.autoStart.level.restartsOnCrash
                )
            }
        )
    }

    /// The transient live-apply confirmation: "Updating…" while a
    /// change is in flight, then a green check + a level-specific
    /// line that fades on its own (mirrors the key recorder's
    /// `LiveApplyCaption`). Nothing shows at rest, on the initial
    /// read, or on the greyed unregisterable control — only after a
    /// user-driven change, because the changes apply live and there
    /// is no Save to press.
    @ViewBuilder private var confirmation: some View {
        if model.autoStartBusy {
            Text(L("general.login_item.updating", "Updating…"))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let applied = model.autoStartApplied {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(confirmationText(applied))
            }
            .font(.caption)
            .foregroundStyle(.green)
            .transition(.opacity)
        }
    }

    /// The line each applied level confirms — present tense, naming
    /// what will now happen, never a "saved" past tense (nothing was
    /// staged).
    private func confirmationText(_ level: AutoStartLevel) -> String {
        switch level {
        case .off:
            L(
                "general.login_item.applied_off",
                "KiwiDesk won\u{2019}t start on its own."
            )
        case .atLogin:
            L(
                "general.login_item.applied_at_login",
                "KiwiDesk will open at login."
            )
        case .atLoginWithAutoRestart:
            L(
                "general.login_item.applied_restart",
                "KiwiDesk will open at login and restart if it "
                    + "crashes."
            )
        }
    }

    @ViewBuilder private var caption: some View {
        if model.autoStart.requiresApproval {
            HStack(spacing: 8) {
                Text(
                    L(
                        "general.login_item.requires_approval",
                        "Requires approval in System Settings"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Button(
                    L(
                        "general.login_item.open_login_items",
                        "Open Login Items"
                    )
                ) {
                    LoginItemManager.openSystemSettingsLoginItems()
                }
                .controlSize(.small)
            }
        } else if model.autoStart.unavailable == .translocated {
            unavailableCaption(
                L(
                    "general.login_item.unavailable",
                    "Move KiwiDesk to your Applications folder "
                        + "to turn this on."
                )
            )
        } else if model.autoStart.unavailable == .notBundled {
            unavailableCaption(
                L(
                    "general.login_item.unavailable_binary",
                    "Available only when running the KiwiDesk app."
                )
            )
        }
    }

    /// Shared styling for the two greyed-state captions.
    private func unavailableCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
