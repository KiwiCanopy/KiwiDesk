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
                    // toggle can be driven right now. The
                    // durable reason (an unregisterable copy —
                    // bare binary or translocated download)
                    // comes from the gate resolver, not a
                    // predicate re-derived here, so the grey and
                    // the census-declared gate cannot drift; the
                    // transient load/write block is added on top
                    // (#342, #171).
                    .disabled(loginInert)
            }
            confirmation
            caption
        }
        .onAppear { model.refreshAutoStart() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in model.refreshAutoStart() }
    }

    /// The design's own words. It deliberately does NOT say
    /// "and keep it running": that becomes false the moment the
    /// Advanced row is switched off, and item 16 rules that "a
    /// label that rewrites itself is worse than one that is
    /// simply always true".
    private var startLabel: String {
        L(
            "general.login_item.start",
            "Start KiwiDesk when I log in"
        )
    }

    /// The one field-level `?` (#94). It names the supervision
    /// half and points at the Advanced row rather than describing
    /// three picker levels that no longer exist.
    private var startHelp: String {
        L(
            "general.login_item.start_help",
            "KiwiDesk opens when you sign in, so your windows are "
                + "arranged from the start. It also keeps itself "
                + "running if it ever stops — switch that off "
                + "under Advanced if you would rather it did not."
        )
    }

    /// This row's half of the folded level: does KiwiDesk start
    /// itself at all.
    ///
    /// **Turning it on brings crash-restart with it** (item 16,
    /// "on by default"). That is the north star's "approachable
    /// by default, powerful on demand" applied to one row: the
    /// obvious answer for someone who just wants KiwiDesk running
    /// is *both*, and the design's own argument is that this
    /// "reconstructs the third state for anyone who wants
    /// login-without-restart, without making every user read
    /// three options to pick the obvious one". The third state is
    /// reached by switching the Advanced row off afterwards.
    ///
    /// **A login-without-restart choice does not survive being
    /// switched off and on again**, and it cannot: the level is
    /// read through from the OS with nothing cached, and `.off`
    /// erases the distinction — a copy that never wanted restart
    /// and a copy that was simply never started both read as
    /// `.off`. So turning login back on has no prior answer to
    /// restore and takes the default. Storing one would mean a
    /// preference the OS does not have, which is the drift
    /// read-through exists to prevent.
    ///
    /// The refusal on an unregisterable copy lives in
    /// `SettingsModel.setAutoStart`, not here: the harm is a
    /// filesystem/launchd side effect (a LaunchAgent written
    /// against an ephemeral `.build` or translocated path, which
    /// read-through cannot undo), so it must not depend on a view
    /// having disabled the control.
    /// The toggle's greyed state: the resolver's durable reason
    /// for this row (an unregisterable copy), or the transient
    /// load/write block that is not a gate reason.
    private var loginInert: Bool {
        model.autoStartLoading
            || model.generalGates
                .inertReason(for: .general(.startAtLogin)) != nil
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { model.autoStart.level.opensAtLogin },
            set: { on in
                model.setAutoStart(
                    openAtLogin: on,
                    restartOnCrash: on
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

    /// The row's standing caption, from the design's own words
    /// (digest 14b): it says where the setting LIVES, which is
    /// what makes the read-through behaviour legible — flip it in
    /// System Settings and this row follows, because there is no
    /// second copy here. The conditional captions below add to
    /// it rather than replace it; approval and unavailability are
    /// states of the same fact.
    @ViewBuilder private var caption: some View {
        Text(
            L(
                "general.login_item.stored_by_macos",
                "Read live from macOS, stored there too — may "
                    + "need approval in System Settings."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
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
                .settingsActionButton()
            }
        } else if let reason = model.generalGates.inertReason(
            for: .general(.startAtLogin)
        ) {
            // The unavailable sentence, named once by the gate
            // help for the specific cause — the same source the
            // Advanced row reads, so the two rows cannot describe
            // one status two ways.
            unavailableCaption(GeneralGateHelp.sentence(for: reason))
        }
    }

    /// Shared styling for the two greyed-state captions.
    private func unavailableCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
